import Foundation

/// ULID: 48 бит времени (мс) + 80 бит случайности, Crockford Base32, 26 символов (R-35).
/// Сортировка строк совпадает с порядком по времени создания.
public enum ULID {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static func make(date: Date = Date()) -> String {
        var rng = SystemRandomNumberGenerator()
        return make(ms: UInt64(max(0, date.timeIntervalSince1970 * 1000)), using: &rng)
    }

    public static func make<R: RandomNumberGenerator>(ms: UInt64, using rng: inout R) -> String {
        var out = [Character](repeating: "0", count: 26)
        var t = ms
        for i in stride(from: 9, through: 0, by: -1) {
            out[i] = alphabet[Int(t & 31)]
            t >>= 5
        }
        for i in 10..<26 { out[i] = alphabet[Int(rng.next() & 31)] }
        return String(out)
    }

    public static func isValid(_ s: String) -> Bool {
        s.count == 26 && s.allSatisfy { alphabet.contains($0) }
    }
}
