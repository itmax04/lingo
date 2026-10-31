// Ported from Interview Copilot (`Sources/CopilotCore/LLM/SSEClient.swift` and `Net/HTTPTransport.swift`, commit cf0e764).
// Change for R-29: on an HTTP error the `retry-after` header is read.
import Foundation

/// A Server-Sent Events event.
public struct SSEEvent: Sendable, Equatable {
    public var event: String?
    public var data: String
}

/// Streaming HTTP: status and body lines. Replaced in tests.
public protocol StreamingTransport: Sendable {
    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, Error>)
}

/// Plain HTTP (model list, key check).
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport, StreamingTransport {
    let session: URLSession

    public init(session: URLSession = URLSessionTransport.makeSession()) {
        self.session = session
    }

    public static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    public func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, Error>) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse("not HTTP") }
        let stream = AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines { continuation.yield(line) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (http, stream)
    }
}

/// SSE parsing: `event:` / `data:` lines, an event ends with an empty line.
/// `URLSession.AsyncBytes.lines` skips empty lines, so a new event also starts at a new `data:`.
public struct SSEParser {
    private var event: String?
    private var data: [String] = []

    public init() {}

    public mutating func feed(_ line: String) -> [SSEEvent] {
        var out: [SSEEvent] = []
        if line.isEmpty {
            if let e = flush() { out.append(e) }
            return out
        }
        if line.hasPrefix(":") { return out }
        let (field, value) = Self.split(line)
        switch field {
        case "event":
            if !data.isEmpty, let e = flush() { out.append(e) }
            event = value
        case "data":
            if !data.isEmpty, let e = flush() { out.append(e) }
            data.append(value)
        default:
            break
        }
        return out
    }

    public mutating func finish() -> SSEEvent? { flush() }

    private mutating func flush() -> SSEEvent? {
        defer { event = nil; data = [] }
        guard !data.isEmpty else { return nil }
        return SSEEvent(event: event, data: data.joined(separator: "\n"))
    }

    static func split(_ line: String) -> (String, String) {
        guard let colon = line.firstIndex(of: ":") else { return (line, "") }
        var value = line[line.index(after: colon)...]
        if value.hasPrefix(" ") { value = value.dropFirst() }
        return (String(line[..<colon]), String(value))
    }
}

enum SSE {
    /// Opens the stream: on a non-2xx status reads the body and throws `LLMError.http` with the error text (without the key) and `retry-after`.
    static func open(_ request: URLRequest, transport: StreamingTransport, key: String) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        try await openWithHeaders(request, transport: transport, key: key).1
    }

    /// The same, plus remaining quota from the headers of a successful response (R-52).
    static func openWithHeaders(_ request: URLRequest, transport: StreamingTransport, key: String) async throws -> (RateLimitSnapshot, AsyncThrowingStream<SSEEvent, Error>) {
        let response: HTTPURLResponse
        let lines: AsyncThrowingStream<String, Error>
        do {
            (response, lines) = try await transport.lines(for: request)
        } catch let error as URLError {
            throw error.code == .cancelled ? LLMError.cancelled : LLMError.network(error.localizedDescription)
        }
        guard (200..<300).contains(response.statusCode) else {
            var body = ""
            do {
                for try await line in lines {
                    body += line
                    if body.count > 4000 { break }
                }
            } catch {}
            throw LLMError.http(status: response.statusCode, message: errorMessage(body, key: key),
                                retryAfter: retryAfter(response))
        }
        let snapshot = RateLimitSnapshot(headers: response.allHeaderFields)
        return (snapshot, AsyncThrowingStream { continuation in
            let task = Task {
                var parser = SSEParser()
                do {
                    for try await line in lines {
                        for e in parser.feed(line) { continuation.yield(e) }
                    }
                    if let e = parser.finish() { continuation.yield(e) }
                    continuation.finish()
                } catch let error as URLError {
                    continuation.finish(throwing: error.code == .cancelled ? LLMError.cancelled : LLMError.network(error.localizedDescription))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        })
    }

    /// `retry-after`: seconds or an HTTP date.
    static func retryAfter(_ r: HTTPURLResponse) -> Double? {
        guard let v = r.value(forHTTPHeaderField: "retry-after")?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        if let s = Double(v) { return max(0, s) }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let d = f.date(from: v) { return max(0, d.timeIntervalSinceNow) }
        return nil
    }

    static func errorMessage(_ body: String, key: String) -> String {
        var message = ""
        if let data = body.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) {
            let dict = (json as? [String: Any]) ?? ((json as? [[String: Any]])?.first ?? [:])
            if let error = dict["error"] as? [String: Any], let m = error["message"] as? String { message = m }
            else if let m = dict["message"] as? String { message = m }
            else if let m = dict["error"] as? String { message = m }
        }
        // 400 characters: on Groq the limit kind ("tokens per day (TPD)") comes after the model and organization names.
        return redact(String(message.prefix(400)), key: key)
    }

    /// The key value and the organization id never appear in the error text (R-48).
    static func redact(_ s: String, key: String) -> String {
        var t = s.replacingOccurrences(of: #"org_[A-Za-z0-9]+"#, with: "org_…", options: .regularExpression)
        if key.count >= 8 { t = t.replacingOccurrences(of: key, with: "[key]") }
        return t
    }

    static func json(_ data: String) -> [String: Any]? {
        guard let d = data.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
}
