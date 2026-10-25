// Перенесено из Interview Copilot (`Sources/CopilotCore/LLM/SSEClient.swift` и `Net/HTTPTransport.swift`, коммит cf0e764).
// Изменение для R-29: при ошибке HTTP читается заголовок `retry-after`.
import Foundation

/// Событие Server-Sent Events.
public struct SSEEvent: Sendable, Equatable {
    public var event: String?
    public var data: String
}

/// Потоковый HTTP: статус и строки тела. Подменяется в тестах.
public protocol StreamingTransport: Sendable {
    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, Error>)
}

/// Обычный HTTP (список моделей, проверка ключа).
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
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse("не HTTP") }
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

/// Разбор SSE: строки `event:` / `data:`, событие заканчивается пустой строкой.
/// `URLSession.AsyncBytes.lines` пропускает пустые строки, поэтому новое событие начинается и с нового `data:`.
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
    /// Открывает поток: при статусе не 2xx читает тело и бросает `LLMError.http` с текстом ошибки (без ключа) и `retry-after`.
    static func open(_ request: URLRequest, transport: StreamingTransport, key: String) async throws -> AsyncThrowingStream<SSEEvent, Error> {
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
        return AsyncThrowingStream { continuation in
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
        }
    }

    /// `retry-after`: секунды или HTTP-дата.
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
        return redact(String(message.prefix(200)), key: key)
    }

    /// Значение ключа никогда не попадает в текст ошибки (R-48).
    static func redact(_ s: String, key: String) -> String {
        guard key.count >= 8 else { return s }
        return s.replacingOccurrences(of: key, with: "[key]")
    }

    static func json(_ data: String) -> [String: Any]? {
        guard let d = data.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
}
