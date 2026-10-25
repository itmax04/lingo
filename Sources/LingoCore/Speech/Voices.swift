@preconcurrency import AVFoundation
import Foundation

/// Голоса озвучивания (R-13): по умолчанию лучший установленный голос языка — premium, затем enhanced, затем default.
public enum Voices {
    public struct Info: Sendable, Hashable, Identifiable {
        public var id: String
        public var name: String
        public var language: String
        public var quality: Int
        public var qualityTitle: String { quality >= 3 ? "Premium" : (quality == 2 ? "Enhanced" : "Default") }
    }

    static func qualityRank(_ v: AVSpeechSynthesisVoice) -> Int {
        switch v.quality {
        case .premium: 3
        case .enhanced: 2
        default: 1
        }
    }

    /// Предпочтительные локали языка (первая — лучшая).
    static func locales(_ l: Lang) -> [String] {
        switch l {
        case .en: ["en-US", "en-GB", "en-AU", "en-IE", "en-CA"]
        case .de: ["de-DE", "de-AT", "de-CH"]
        case .ru: ["ru-RU"]
        }
    }

    public static func available(_ l: Lang) -> [Info] {
        let locs = locales(l)
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { locs.contains($0.language) && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .sorted {
                let a = (qualityRank($0), -(locs.firstIndex(of: $0.language) ?? 9)), b = (qualityRank($1), -(locs.firstIndex(of: $1.language) ?? 9))
                return a != b ? a > b : $0.name < $1.name
            }
            .map { Info(id: $0.identifier, name: $0.name, language: $0.language, quality: qualityRank($0)) }
    }

    /// Голос по идентификатору из настроек или лучший доступный.
    public static func voice(for l: Lang, preferred id: String?) -> AVSpeechSynthesisVoice? {
        if let id, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        if let best = available(l).first { return AVSpeechSynthesisVoice(identifier: best.id) }
        return AVSpeechSynthesisVoice(language: locales(l)[0])
    }

    /// Только голос плохого качества — предложить скачать улучшенный (R-13).
    public static func needsBetterVoice(_ l: Lang) -> Bool { (available(l).first?.quality ?? 0) < 2 }
}

/// Деление фразы на части для «Медленнее» (R-15): по знакам препинания и смысловым группам, без слишком длинных частей.
public enum SlowChunks {
    public static func split(_ text: String, maxWords: Int = 5) -> [String] {
        var parts: [String] = []
        var cur = ""
        for ch in text {
            cur.append(ch)
            if ",.;:!?…—–".contains(ch) {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { parts.append(t) }
                cur = ""
            }
        }
        let tail = cur.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { parts.append(tail) }
        // Длинные части делятся по смысловым связкам (союзы, предлоги), иначе — по maxWords слов.
        let joiners: Set<String> = ["und", "aber", "oder", "weil", "dass", "wenn", "als", "mit", "in", "am", "im", "zu", "nach",
                                    "and", "but", "or", "because", "that", "when", "with", "in", "at", "to", "for",
                                    "и", "но", "или", "потому", "что", "когда", "в", "на", "с"]
        var out: [String] = []
        for p in parts {
            let words = p.split(separator: " ").map(String.init)
            guard words.count > maxWords else { out.append(p); continue }
            var chunk: [String] = []
            for w in words {
                let key = w.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if chunk.count >= 2, joiners.contains(key) || chunk.count >= maxWords {
                    out.append(chunk.joined(separator: " "))
                    chunk = []
                }
                chunk.append(w)
            }
            if !chunk.isEmpty { out.append(chunk.joined(separator: " ")) }
        }
        return out
    }
}

/// Темп озвучивания (R-15): базовый из настроек; «Медленнее» ×0,75, повторно ×0,6 (минимум).
public struct SpeechPace: Sendable, Hashable, Codable {
    /// Базовый темп, доля от стандартного (`AVSpeechUtteranceDefaultSpeechRate`).
    public var base: Double = 1.0
    public static let slowSteps: [Double] = [1.0, 0.75, 0.6]

    public init(base: Double = 1.0) { self.base = base }

    /// Значение `AVSpeechUtterance.rate` для множителя.
    public func rate(multiplier: Double) -> Float {
        let r = Double(AVSpeechUtteranceDefaultSpeechRate) * base * multiplier
        return Float(min(Double(AVSpeechUtteranceMaximumSpeechRate), max(Double(AVSpeechUtteranceMinimumSpeechRate), r)))
    }
}
