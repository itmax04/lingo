import Foundation
import LingoCore

/// Eval `audio` (P-04): WER, определение языка, задержка, память для движка распознавания. Порогов нет —
/// сравнение движков (пороги AC-16 — на живых фразах). Аудио: scripts/make-audio-fixtures.sh.
enum STTEval {
    struct Item: Decodable { var set: String; var id: String; var file: String; var ref: String; var study: String; var lang: String }
    struct Row: Encodable {
        var id: String; var set: String; var mode: String; var hyp: String; var wer: Double
        var lang: String; var expectLang: String; var langOK: Bool?; var ms: Double; var audioSec: Double
    }
    struct Summary: Encodable { var set: String; var mode: String; var n: Int; var meanWER: Double; var understood: Int; var langAccuracy: Double?; var medianMs: Double; var p90Ms: Double }
    struct Report: Encodable { var engine: String; var loadMs: Double; var footprintAfterLoadMB: Double; var peakFootprintMB: Double; var summaries: [Summary]; var rows: [Row] }

    static func run(engine id: String, set: String, forcedMixed: Bool) async throws -> Int32 {
        let manifestURL = URL(fileURLWithPath: set).appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else {
            print("stt: нет \(manifestURL.path) — запустите scripts/make-audio-fixtures.sh")
            return 2
        }
        let items = try JSONDecoder().decode([Item].self, from: data)
        let t0 = Date()
        let engine: SpeechRecognizer
        if id.hasPrefix("whisper:") {
            // whisper:<модель>[@стратегия[@ctx]] — стратегия: detect | dual | smallDetect; ctx — минимум кадров урезанного контекста.
            let parts = id.dropFirst("whisper:".count).split(separator: "@").map(String.init)
            let w = try WhisperEngine(modelPath: parts[0])
            if parts.count > 1, let st = WhisperEngine.LanguageStrategy(rawValue: parts[1]) { w.strategy = st }
            if parts.count > 2, let c = Int(parts[2]) { w.reducedContext = true; w.minAudioContext = c }
            if w.strategy == .smallDetect {
                let small = (parts[0] as NSString).deletingLastPathComponent + "/" + WhisperModel.smallQ5.file
                w.detector = try WhisperEngine(modelPath: small)
            }
            engine = w
        } else if id == "apple" {
            guard AppleSpeechEngine.authorized else {
                print("stt: NOT RUN — у этого процесса нет разрешения на распознавание речи (запускать из Lingo.app после H-2)")
                return 3
            }
            engine = AppleSpeechEngine()
        } else {
            print("stt: неизвестный движок \(id)")
            return 2
        }
        let loadMs = Date().timeIntervalSince(t0) * 1000
        let afterLoad = Memory.physFootprint()
        var peak = afterLoad
        var rows: [Row] = []
        let base = URL(fileURLWithPath: set)
        for it in items {
            let samples = try AudioFileReader.read(base.appendingPathComponent(it.file))
            let study = Lang(rawValue: it.study) ?? .en
            var modes: [(String, Lang?)] = [("auto", nil)]
            if it.lang == "mixed" && forcedMixed { modes.append(("forced-ru", .ru)) }
            for (mode, forced) in modes {
                let tr = try await engine.transcribe(samples, candidates: [study, .ru], forced: forced)
                peak = max(peak, Memory.physFootprint())
                let w = WER.compute(ref: it.ref, hyp: tr.text)
                let langOK: Bool? = it.lang == "mixed" ? nil : (tr.lang.rawValue == it.lang)
                rows.append(Row(id: it.id, set: it.set, mode: mode, hyp: tr.text, wer: w, lang: tr.lang.rawValue, expectLang: it.lang,
                                langOK: langOK, ms: tr.elapsedMs, audioSec: tr.audioSeconds))
            }
        }
        var sums: [Summary] = []
        for s in ["en", "de", "ru", "mixed"] {
            for mode in ["auto", "forced-ru"] {
                let r = rows.filter { $0.set == s && $0.mode == mode }
                guard !r.isEmpty else { continue }
                let ms = r.map(\.ms).sorted()
                let langRows = r.compactMap(\.langOK)
                sums.append(Summary(set: s, mode: mode, n: r.count, meanWER: r.map(\.wer).reduce(0, +) / Double(r.count),
                                    understood: r.filter { $0.wer <= 0.25 }.count,
                                    langAccuracy: langRows.isEmpty ? nil : Double(langRows.filter { $0 }.count) / Double(langRows.count),
                                    medianMs: ms[ms.count / 2], p90Ms: ms[min(ms.count - 1, Int(Double(ms.count) * 0.9))]))
            }
        }
        let rep = Report(engine: engine.id, loadMs: loadMs, footprintAfterLoadMB: Memory.mb(afterLoad), peakFootprintMB: Memory.mb(peak),
                         summaries: sums, rows: rows)
        let safe = id.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: ":", with: "-") ?? engine.id
        let path = try EvalIO.writeOut("stt-\(safe).json", rep)
        let variant = id.split(separator: "@").dropFirst().joined(separator: "@")
        print(String(format: "stt %@ [%@]: загрузка %.0f мс, память после загрузки %.0f МБ, пик %.0f МБ", engine.id, variant.isEmpty ? "detect" : variant, loadMs, rep.footprintAfterLoadMB, rep.peakFootprintMB))
        for s in sums {
            print(String(format: "  %-5@ %-9@ n=%2d WER=%.1f%% понятно(WER≤25%%)=%d/%d язык=%@ задержка медиана %.0f мс p90 %.0f мс",
                         s.set, s.mode, s.n, s.meanWER * 100, s.understood, s.n,
                         s.langAccuracy.map { String(format: "%.0f%%", $0 * 100) } ?? "—", s.medianMs, s.p90Ms))
        }
        print("out: \(path)")
        return 0
    }
}
