import Foundation
import LingoCore

/// Разбивка задержки whisper на нескольких файлах (P-04): определение языка и прогоны, GPU/CPU, полный/урезанный контекст.
enum STTBench {
    static func run(model: String, files: [String], gpu: Bool, reduced: Bool, threads: Int32, minCtx: Int = 64, strategy: String? = nil, context: String? = nil) throws -> Int32 {
        let e = try WhisperEngine(modelPath: model, useGPU: gpu, threads: threads)
        e.reducedContext = reduced
        e.minAudioContext = minCtx
        if let st = strategy.flatMap(WhisperEngine.LanguageStrategy.init(rawValue:)) { e.strategy = st }
        for (i, f) in files.enumerated() {
            let s = try AudioFileReader.read(URL(fileURLWithPath: f))
            let t = try e.transcribeSync(s, candidates: [.de, .ru], forced: nil, context: context)
            let tm = e.lastTimings
            print(String(format: "%d %@ audio=%.1fs total=%.0fms detect=%.0fms runs=%@ lang=%@ «%@»", i, (f as NSString).lastPathComponent,
                         t.audioSeconds, t.elapsedMs, tm.detectMs, tm.runs.map { String(format: "%.0f", $0) }.joined(separator: "+"),
                         t.lang.rawValue, String(t.text.prefix(50))))
        }
        return 0
    }
}

enum ChunkDebug {
    static func run(files: [String]) throws -> Int32 {
        for f in files {
            let s = try AudioFileReader.read(URL(fileURLWithPath: f))
            let ch = WhisperEngine.speechChunks(s)
            // Профиль уровня по 100 мс — видно, есть ли паузы между частями.
            var prof: [String] = []
            var i = 0
            while i < s.count { prof.append(String(format: "%.0f", EnergyVAD.rmsDB(s[i..<min(s.count, i + 1600)]))); i += 1600 }
            print((f as NSString).lastPathComponent, ch.map { String(format: "%.2f-%.2f", Double($0.lowerBound) / 16000, Double($0.upperBound) / 16000) }, prof.joined(separator: " "))
        }
        return 0
    }
}
