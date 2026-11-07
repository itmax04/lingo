import Foundation

/// The one list of markers for talk about pronunciation (product rule 7). The `no_pronunciation` eval rule and the runtime
/// filter of the exam debrief both read it, so they cannot drift apart.
public enum PronunciationFilter {
    /// Words about pronunciation, sounds, accent and "softer/harder/clearer" (ru, de, en) — whole-word regular expressions (language data).
    /// Everyday idioms "sounds like", "klingt wie", "звучит как" and "акцентировать (внимание)" are not about pronunciation (false positives in run1, D-20).
    public static let markers: [String] = [
        "произнош", "произнес", "произнёс", "произноси", "выговор", "\\bакцент(а|у|ом|е|ы|ов)?\\b", "интонац", "ударени",
        "мягче", "твёрже", "тверже", "чётче", "четче", "\\bзвук(а|и|ов|ом)?\\b",
        "aussprache", "aussprech", "ausgesproch", "\\bakzent(e|s)?\\b", "betonung", "weicher", "härter", "deutlicher aus",
        "pronunciation", "pronounc", "\\baccents?\\b", "intonation", "softer", "harder sound", "your sound",
    ]

    /// Lower case with "ё" → "е" and the typographic apostrophe → "'" (the form the markers are matched in).
    public static func normalized(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "ё", with: "е").replacingOccurrences(of: "’", with: "'")
    }

    /// True when the text contains any marker.
    public static func matches(_ text: String) -> Bool {
        let low = normalized(text)
        return markers.contains { low.range(of: normalized($0), options: .regularExpression) != nil }
    }

    /// The text without every line that matches a marker. Blank lines between kept lines stay; leading and trailing blanks go.
    public static func removingMarkedLines(from text: String) -> String {
        let kept = text.split(separator: "\n", omittingEmptySubsequences: false).filter { !matches(String($0)) }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
