import CryptoKit
import Foundation

/// Модели whisper (ADR-0001 п. 6): только официальный репозиторий Hugging Face по HTTPS и проверка SHA256 (CLAUDE.md).
/// Суммы — LFS oid из `https://huggingface.co/api/models/ggerganov/whisper.cpp/tree/main`, проверено 2026-10-25 (handoff P-04).
public struct WhisperModel: Sendable, Hashable, Identifiable {
    public var id: String { file }
    public var file: String
    public var title: String
    public var size: Int64
    public var sha256: String
    public var url: URL

    public static let largeV3TurboQ5 = WhisperModel(
        file: "ggml-large-v3-turbo-q5_0.bin", title: "large-v3-turbo q5_0", size: 574_041_195,
        sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!)
    public static let smallQ5 = WhisperModel(
        file: "ggml-small-q5_1.bin", title: "small q5_1", size: 190_085_487,
        sha256: "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin")!)

    public static let catalog: [WhisperModel] = [largeV3TurboQ5, smallQ5]
}

public struct ModelStore: Sendable {
    public let dir: URL
    /// Папки, откуда модель можно взять APFS-клоном без расхода места (модели Interview Copilot на этом Mac, D-02).
    public let cloneSources: [URL]

    public enum ModelError: Error, CustomStringConvertible {
        case checksum(String)
        case download(String)
        public var description: String {
            switch self {
            case .checksum(let f): "Контрольная сумма не совпала: \(f)"
            case .download(let m): "Загрузка модели: \(m)"
            }
        }
    }

    public init(dir: URL, cloneSources: [URL] = []) {
        self.dir = dir
        self.cloneSources = cloneSources
    }

    public func path(_ m: WhisperModel) -> URL { dir.appendingPathComponent(m.file) }

    public func isInstalled(_ m: WhisperModel) -> Bool {
        let p = path(m)
        let size = (try? FileManager.default.attributesOfItem(atPath: p.path)[.size] as? NSNumber)?.int64Value
        return size == m.size
    }

    public static func sha256(of url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        var hasher = SHA256()
        while let chunk = try h.read(upToCount: 8 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Готовит модель: уже есть → проверка размера (сумма проверялась при установке); иначе клон или загрузка + SHA256.
    @discardableResult
    public func ensure(_ m: WhisperModel, progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        let dest = path(m)
        if isInstalled(m) { return dest }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tmp = dir.appendingPathComponent(m.file + ".part")
        try? FileManager.default.removeItem(at: tmp)
        var got = false
        for src in cloneSources {
            let s = src.appendingPathComponent(m.file)
            guard FileManager.default.fileExists(atPath: s.path) else { continue }
            // На APFS copyItem делает клон (clonefile): данные не копируются, место не расходуется.
            if (try? FileManager.default.copyItem(at: s, to: tmp)) != nil { got = true; break }
        }
        if !got {
            let (file, response) = try await URLSession.shared.download(from: m.url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ModelError.download("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)") }
            try FileManager.default.moveItem(at: file, to: tmp)
        }
        guard try Self.sha256(of: tmp) == m.sha256 else {
            try? FileManager.default.removeItem(at: tmp)
            throw ModelError.checksum(m.file)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        Log.speech.notice("model installed: \(m.file, privacy: .public) via \(got ? "clone" : "download", privacy: .public)")
        return dest
    }

    public func remove(_ m: WhisperModel) throws {
        if FileManager.default.fileExists(atPath: path(m).path) { try FileManager.default.removeItem(at: path(m)) }
    }

    /// Стандартные пути на Mac.
    public static var macDefault: ModelStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ModelStore(dir: support.appendingPathComponent("Lingo/models", isDirectory: true),
                          cloneSources: [support.appendingPathComponent("InterviewCopilot/models", isDirectory: true)])
    }
}
