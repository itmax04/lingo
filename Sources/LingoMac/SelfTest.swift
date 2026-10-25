import Foundation
import LingoCore

/// `Lingo --selftest <wav>`: сквозная проверка голосового хода на настоящих компонентах без окна и микрофона:
/// файл (синтетика evals/audio) → VAD → сегментация → whisper → цепочка Groq (ключ из Связки ключей) → протокол → «озвучка» без звука.
/// История — во временной папке. Печатает расшифровку, ответ и отметки хода (R-47).
@MainActor
enum SelfTest {
    final class SilentSink: SpeechSink {
        var spoken: [String] = []
        var firstAt: Double?
        var until: Double = 0
        var micMuted = false
        var isSpeaking: Bool { MetricsRecorder.now() < until }
        func speak(_ text: String, lang: Lang, voiceID: String?, rate: Float, pauseAfter: Double, tag: Int) {
            spoken.append(text)
            if firstAt == nil { firstAt = MetricsRecorder.now() }
            until = max(until, MetricsRecorder.now()) + Double(text.count) * 0.06
        }
        func stopSpeaking() -> (tag: Int, charOffset: Int)? { until = 0; return nil }
    }

    static func run(files: [String], lang: Lang) async -> Int32 {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-selftest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let settings = SettingsStore().load()
        guard settings.llm.hasUsableKey else { print("selftest: нет ключа"); return 1 }
        do {
            let store = try JournalStore(base: base, deviceName: "selftest", deviceID: "mac-selftest")
            let secrets = KeychainStore()
            let engine = DialogEngine(store: store) { ChainFactory.chain(settings: settings.llm, secrets: secrets) }
            let sid = try await engine.createSession(SessionSettings(lang: lang, mode: .questions, topic: lang == .de ? "Wohnort" : "Home",
                                                                     level: "A2", corrections: [.inline]))
            let path = try await ModelStore.macDefault.ensure(.largeV3TurboQ5)
            let w = try await Task.detached { () -> WhisperEngine in
                let w = try WhisperEngine(modelPath: path.path)
                w.strategy = .dual; w.reducedContext = true; w.minAudioContext = 512
                return w
            }.value
            let sink = SilentSink()
            let metrics = MetricsRecorder(dir: base.appendingPathComponent("metrics"))
            let tc = TurnController(engine: engine, recognizer: w, sink: sink, metrics: metrics, voice: settings.voice) {
                nil
            }
            var ctx: TurnController.Context?
            tc.context = { ctx }
            for f in files {
                let st = await store.state
                ctx = TurnController.Context(session: st.sessions[sid]!, lastAssistant: st.messages[sid]?.last { $0.role == .assistant },
                                             lastUser: nil, phrases: [])
                tc.startContinuous()
                let samples = try AudioFileReader.read(URL(fileURLWithPath: f))
                func feed(_ s: [Float]) async {
                    var i = 0
                    while i < s.count {
                        let n = min(320, s.count - i)
                        tc.feed(Array(s[i..<(i + n)]))
                        i += n
                        try? await Task.sleep(for: .milliseconds(20))   // реальное время
                    }
                }
                let noise = (0..<16_000).map { _ in Float.random(in: -0.0025...0.0025) }
                await feed(noise)
                sink.firstAt = nil
                await feed(samples)
                await feed(noise + noise)
                // Ждём ответа и «озвучки».
                for _ in 0..<300 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if sink.firstAt != nil && !sink.isSpeaking && tc.state == .listening { break }
                }
                let msgs = await store.state.messages[sid] ?? []
                print("— \((f as NSString).lastPathComponent)")
                if let u = msgs.last(where: { $0.role == .user }) { print("  user (\(u.lang.rawValue)): \(u.text)") }
                if let a = msgs.last(where: { $0.role == .assistant }) { print("  assistant [\(a.source ?? "-")]: \(a.spokenText)") }
            }
            tc.stopVoice()
            let files = (try? FileManager.default.contentsOfDirectory(atPath: base.appendingPathComponent("metrics").path)) ?? []
            for mf in files {
                let text = (try? String(contentsOf: base.appendingPathComponent("metrics").appendingPathComponent(mf), encoding: .utf8)) ?? ""
                for line in text.split(separator: "\n") {
                    guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any], o["type"] as? String == "turn",
                          let se = o["speech_end"] as? Double else { continue }
                    func d(_ k: String) -> String { (o[k] as? Double).map { String(format: "%.2f с", $0 - se) } ?? "—" }
                    print("  speech_end→stt_final \(d("stt_final")), →llm_first_token \(d("llm_first_token")), →first_audio \(d("first_audio")), →reply_end \(d("reply_end")), память \(o["footprint_mb"] ?? "-") МБ")
                }
            }
            return 0
        } catch {
            print("selftest: \(error)")
            return 1
        }
    }
}
