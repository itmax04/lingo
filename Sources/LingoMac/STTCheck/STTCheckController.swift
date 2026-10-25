import AppKit
import Foundation
import LingoCore
import Observation

/// Живая проверка распознавания (H-2, H-4; AC-16). Звук — только в памяти (R-08); в файл пишутся тексты и числа.
/// Каждая фраза распознаётся whisper (выбранная настройка P-04) и Apple Speech (если есть разрешение) — сравнение движков.
@MainActor
@Observable
final class STTCheckController {
    struct Phrase: Codable, Hashable { var id: String; var lang: String; var study: String; var text: String }
    struct Step: Hashable { var phrase: Phrase; var forced: Bool }
    struct EngineResult: Codable, Hashable { var engine: String; var text: String; var lang: String; var wer: Double; var ms: Double }
    struct Result: Codable, Hashable {
        var id: String; var lang: String; var mode: String; var ref: String
        var audioSec: Double
        var results: [EngineResult]
        /// Оценка владельца: понятно ли распознанное (AC-16: «WER ≤ 25% или владелец принял»).
        var accepted: Bool?
    }

    let part: String
    private(set) var steps: [Step] = []
    var index = 0
    private(set) var results: [String: Result] = [:]
    var recording = false
    var busy = false
    var status = ""
    var levels: [Float] = []
    var permissionProblem: String?
    private var voice: VoiceIO?
    private var buffer = UtteranceBuffer()
    private var segmenter = TurnSegmenter()
    private var vad = EnergyVAD(config: VoiceDefaults.vad)
    private var sampleClock = 0
    private var whisper: WhisperEngine?
    private let apple = AppleSpeechEngine()

    init(part: String) {
        self.part = part
        if let url = Bundle.main.url(forResource: "live-phrases", withExtension: "json")
            ?? URL(string: "file://" + FileManager.default.currentDirectoryPath + "/Resources/live-phrases.json"),
           let data = try? Data(contentsOf: url),
           let all = try? JSONDecoder().decode([String: AnyDecodable].self, from: data),
           let list = all[part]?.phrases {
            steps = list.flatMap { p in p.lang == "mixed" ? [Step(phrase: p, forced: false), Step(phrase: p, forced: true)] : [Step(phrase: p, forced: false)] }
        }
        loadSaved()
    }

    var current: Step? { steps.indices.contains(index) ? steps[index] : nil }
    func key(_ s: Step) -> String { s.phrase.id + (s.forced ? "-button" : "") }
    var currentResult: Result? { current.flatMap { results[key($0)] } }

    static var outURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lingo/evals", isDirectory: true)
    }
    var fileURL: URL { Self.outURL.appendingPathComponent("live-stt-\(part).json") }

    // MARK: Подготовка

    func prepare() async {
        status = "Разрешения…"
        if Permissions.microphone == .notDetermined { _ = await Permissions.requestMicrophone() }
        if Permissions.speech == .notDetermined { _ = await Permissions.requestSpeech() }
        if Permissions.microphone != .granted {
            permissionProblem = "Нет доступа к микрофону. Системные настройки → Конфиденциальность и безопасность → Микрофон → включите Lingo."
            return
        }
        status = "Загрузка модели распознавания…"
        do {
            let path = try await ModelStore.macDefault.ensure(.largeV3TurboQ5)
            whisper = try await Task.detached { () -> WhisperEngine in
                let w = try WhisperEngine(modelPath: path.path)
                w.strategy = .dual
                w.reducedContext = true
                w.minAudioContext = 512
                return w
            }.value
        } catch {
            permissionProblem = "Модель распознавания: \(error)"
            return
        }
        let v = VoiceIO()
        v.onSamples = { [weak self] s in Task { @MainActor in self?.feed(s) } }
        do { try v.start(voiceProcessing: true, output: true) } catch {
            permissionProblem = "Микрофон: \(error.localizedDescription) [\(v.startLog.joined(separator: "; "))]"
            return
        }
        voice = v
        let vp = v.voiceProcessing ? "" : " · без эхоподавления"
        status = (Permissions.speech == .granted ? "Готово" : "Готово (Apple Speech без разрешения — только whisper)") + vp
    }

    // MARK: Запись

    func toggleRecording() {
        if recording { finishRecording() } else { startRecording() }
    }

    func startRecording() {
        guard voice != nil, !busy else { return }
        buffer.clear()
        segmenter = TurnSegmenter(config: TurnConfig(silence: 1.5))
        vad.reset()
        sampleClock = 0
        levels = []
        recording = true
        status = "Говорите… (стоп — пробел или пауза 1,5 с)"
    }

    private func feed(_ s: [Float]) {
        guard recording else { return }
        buffer.append(s)
        levels.append(min(1, max(0, (EnergyVAD.rmsDB(s[...]) + 60) / 50)))
        if levels.count > 120 { levels.removeFirst(levels.count - 120) }
        for e in vad.processEvents(s) {
            let t = Double(sampleClock + e.sampleOffset) / 16_000
            _ = e.isSpeech ? segmenter.speechStarted(at: t) : segmenter.speechEnded(at: t - 0.2)
        }
        sampleClock += s.count
        let ev = segmenter.advance(to: Double(sampleClock) / 16_000)
        if ev.contains(where: { if case .utterance = $0 { return true }; return false }) { finishRecording() }
    }

    func finishRecording() {
        guard recording, let step = current else { return }
        recording = false
        let samples = buffer.samples
        buffer.clear()
        guard samples.count > 8_000 else { status = "Слишком коротко — запишите ещё раз"; return }
        busy = true
        status = "Распознаю…"
        let study = Lang(rawValue: step.phrase.study) ?? .en
        let forced: Lang? = step.forced ? .ru : nil
        let w = whisper, apple = self.apple
        Task {
            var out: [EngineResult] = []
            if let w {
                if let t = try? await w.transcribe(samples, candidates: [study, .ru], forced: forced) {
                    out.append(EngineResult(engine: w.id + "@dual@512", text: t.text, lang: t.lang.rawValue,
                                            wer: WER.compute(ref: step.phrase.text, hyp: t.text), ms: t.elapsedMs))
                }
            }
            if AppleSpeechEngine.authorized {
                do {
                    let t = try await apple.transcribe(samples, candidates: [study, .ru], forced: forced)
                    out.append(EngineResult(engine: "apple", text: t.text, lang: t.lang.rawValue,
                                            wer: WER.compute(ref: step.phrase.text, hyp: t.text), ms: t.elapsedMs))
                } catch {
                    out.append(EngineResult(engine: "apple", text: "ошибка: \(error)", lang: "", wer: 1, ms: 0))
                }
            }
            let r = Result(id: step.phrase.id, lang: step.phrase.lang, mode: step.forced ? "button" : "auto", ref: step.phrase.text,
                           audioSec: Double(samples.count) / 16_000, results: out, accepted: nil)
            results[key(step)] = r
            busy = false
            status = "Отметьте: понятно или нет"
            save()
        }
    }

    func mark(_ ok: Bool) {
        guard let s = current, var r = results[key(s)] else { return }
        r.accepted = ok
        results[key(s)] = r
        save()
        next()
    }

    func next() { if index < steps.count - 1 { index += 1; status = "Готово" } else { status = "Все фразы пройдены — напишите «готово» в чат" } }
    func previous() { if index > 0 { index -= 1 } }

    // MARK: Итоги и файл

    struct Summary { var lang: String; var mode: String; var n: Int; var understood: Int; var langOK: Int; var langN: Int }

    func summary(engine prefix: String) -> [Summary] {
        var out: [Summary] = []
        for lang in ["en", "de", "ru", "mixed"] {
            for mode in ["auto", "button"] {
                let rs = results.values.filter { $0.lang == lang && $0.mode == mode }
                guard !rs.isEmpty else { continue }
                var und = 0, lok = 0, ln = 0
                for r in rs {
                    guard let e = r.results.first(where: { $0.engine.hasPrefix(prefix) }) else { continue }
                    if e.wer <= 0.25 || r.accepted == true { und += 1 }
                    if lang != "mixed" { ln += 1; if e.lang == lang { lok += 1 } }
                }
                out.append(Summary(lang: lang, mode: mode, n: rs.count, understood: und, langOK: lok, langN: ln))
            }
        }
        return out
    }

    /// Строки итогов для окна: whisper и Apple рядом.
    func summaryLines() -> [String] {
        let w = summary(engine: "whisper"), a = summary(engine: "apple")
        return w.map { s in
            var line = "\(s.lang.uppercased()) \(s.mode == "button" ? "с кнопкой" : "авто"): понятно \(s.understood)/\(s.n)"
            if s.langN > 0 { line += ", язык \(s.langOK)/\(s.langN)" }
            if let ap = a.first(where: { $0.lang == s.lang && $0.mode == s.mode }) {
                line += "   ·   Apple: \(ap.understood)/\(ap.n)"
                if ap.langN > 0 { line += ", язык \(ap.langOK)/\(ap.langN)" }
            }
            return line
        }
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.outURL, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let d = try? enc.encode(results.values.sorted { $0.id + $0.mode < $1.id + $1.mode }) { try? d.write(to: fileURL, options: .atomic) }
    }

    private func loadSaved() {
        guard let d = try? Data(contentsOf: fileURL), let list = try? JSONDecoder().decode([Result].self, from: d) else { return }
        for r in list { results[r.id + (r.mode == "button" ? "-button" : "")] = r }
        if let first = steps.firstIndex(where: { results[key($0)]?.accepted == nil }) { index = first }
    }

    func stop() { voice?.stop() }
}

/// Декодирование `live-phrases.json`: части `part1`, `part2` и служебное поле `_about`.
struct AnyDecodable: Decodable {
    var phrases: [STTCheckController.Phrase]?
    init(from decoder: Decoder) throws {
        phrases = try? decoder.singleValueContainer().decode([STTCheckController.Phrase].self)
    }
}
