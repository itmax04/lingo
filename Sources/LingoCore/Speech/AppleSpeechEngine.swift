@preconcurrency import AVFoundation
import Foundation
import Speech

/// Apple `SFSpeechRecognizer` на устройстве (ADR-0001 п. 6: на macOS 15 `SpeechAnalyzer` недоступен).
/// Язык реплики: параллельное распознавание по кандидатам {изучаемый, ru} и выбор по средней уверенности сегментов.
public final class AppleSpeechEngine: SpeechRecognizer, @unchecked Sendable {
    public let id = "apple"

    public enum AppleSpeechError: Error, CustomStringConvertible {
        case notAuthorized
        case unavailable(String)
        case failed(String)
        public var description: String {
            switch self {
            case .notAuthorized: "Нет разрешения на распознавание речи"
            case .unavailable(let l): "Распознавание на устройстве недоступно для \(l)"
            case .failed(let m): "Распознавание: \(m)"
            }
        }
    }

    public init() {}

    public static var authorized: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }

    public static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }

    /// Поддерживает ли язык распознавание на устройстве (без отправки звука в сеть, R-08).
    public static func onDeviceSupported(_ l: Lang) -> Bool {
        SFSpeechRecognizer(locale: Locale(identifier: l.localeIdentifier))?.supportsOnDeviceRecognition ?? false
    }

    public func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription {
        guard Self.authorized else { throw AppleSpeechError.notAuthorized }
        let started = DispatchTime.now()
        let langs = forced.map { [$0] } ?? (candidates.isEmpty ? [.en] : candidates)
        let results = try await withThrowingTaskGroup(of: (Lang, String, Float).self) { group in
            for l in langs {
                group.addTask { try await Self.recognize(samples, lang: l, context: context) }
            }
            var out: [(Lang, String, Float)] = []
            for try await r in group { out.append(r) }
            return out
        }
        let best = results.max { $0.2 < $1.2 } ?? (langs[0], "", 0)
        var scores: [Lang: Float] = [:]
        for r in results { scores[r.0] = r.2 }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1e6
        return Transcription(text: best.1, lang: best.0, scores: scores, audioSeconds: Double(samples.count) / 16_000, elapsedMs: elapsed)
    }

    static func recognize(_ samples: [Float], lang: Lang, context: String?) async throws -> (Lang, String, Float) {
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: lang.localeIdentifier)), rec.isAvailable else {
            throw AppleSpeechError.unavailable(lang.localeIdentifier)
        }
        guard rec.supportsOnDeviceRecognition else { throw AppleSpeechError.unavailable(lang.localeIdentifier) }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true
        req.shouldReportPartialResults = false
        req.addsPunctuation = true
        // Контекст разговора (R-51): слова-подсказки.
        if let c = context { req.contextualStrings = Array(c.split(separator: " ").map(String.init).prefix(100)) }
        guard let buf = PCMConverter.buffer(samples) else { throw AppleSpeechError.failed("buffer") }
        req.append(buf)
        req.endAudio()
        final class Once: @unchecked Sendable {
            let lock = NSLock()
            var done = false
            func take() -> Bool { lock.withLock { if done { return false }; done = true; return true } }
        }
        let once = Once()
        return try await withCheckedThrowingContinuation { c in
            let task = rec.recognitionTask(with: req) { result, error in
                if let result, result.isFinal {
                    guard once.take() else { return }
                    let segs = result.bestTranscription.segments
                    let conf = segs.isEmpty ? 0 : segs.map(\.confidence).reduce(0, +) / Float(segs.count)
                    c.resume(returning: (lang, result.bestTranscription.formattedString, conf))
                } else if let error {
                    guard once.take() else { return }
                    // «No speech detected» — пустой результат, а не ошибка.
                    let ns = error as NSError
                    if ns.domain == "kAFAssistantErrorDomain" && (ns.code == 1110 || ns.code == 1101) {
                        c.resume(returning: (lang, "", 0))
                    } else {
                        c.resume(throwing: AppleSpeechError.failed(error.localizedDescription))
                    }
                }
            }
            _ = task
        }
    }
}
