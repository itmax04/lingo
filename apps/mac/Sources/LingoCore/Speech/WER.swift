import Foundation

/// Word error rate for recognition evals (AC-16): case and punctuation normalization, word-level Levenshtein.
public enum WER {
    public static func words(_ s: String) -> [String] {
        var t = s.lowercased().replacingOccurrences(of: "ё", with: "е")
        t = t.unicodeScalars.map { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || $0 == "'" ? String($0) : " " }.joined()
        return t.split(separator: " ").map(String.init)
    }

    public static func compute(ref: String, hyp: String) -> Double {
        let r = words(ref), h = words(hyp)
        guard !r.isEmpty else { return h.isEmpty ? 0 : 1 }
        var prev = Array(0...h.count)
        var cur = [Int](repeating: 0, count: h.count + 1)
        for i in 1...r.count {
            cur[0] = i
            if !h.isEmpty {
                for j in 1...h.count {
                    cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (r[i - 1] == h[j - 1] ? 0 : 1))
                }
            }
            swap(&prev, &cur)
        }
        return Double(prev[h.count]) / Double(r.count)
    }
}
