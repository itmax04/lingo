import Foundation
import Yams

enum EvalIO {
    static func yamlFiles(_ dir: String) throws -> [URL] {
        let u = URL(fileURLWithPath: dir)
        return try FileManager.default.contentsOfDirectory(at: u, includingPropertiesForKeys: nil)
            .filter { ["yaml", "yml"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try YAMLDecoder().decode(T.self, from: String(contentsOf: url, encoding: .utf8))
    }

    /// Run results — `evals/out/` (in .gitignore).
    static func writeOut<T: Encodable>(_ name: String, _ value: T) throws -> String {
        let dir = URL(fileURLWithPath: "evals/out", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = dir.appendingPathComponent(name)
        try enc.encode(value).write(to: url)
        return url.path
    }

    static func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "n/a" : String(format: "%.1f%%", Double(a) * 100 / Double(b)) }
}
