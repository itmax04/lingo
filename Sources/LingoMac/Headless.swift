import Foundation
import LingoCore
import LingoEvalKit

/// Служебные режимы без окна. Печатают только метаданные (провайдер, номер ключа, последние 4 символа, модели).
@MainActor
enum Headless {
    static func checkKeys(showAll: Bool) -> Int32 {
        let store = SettingsStore()
        var settings = store.load()
        let secrets = KeychainStore()
        let verifier = KeyVerifier()
        if settings.llm.keys.isEmpty {
            print("check-keys: ключей нет (Настройки → Ключи и модели)")
            return 1
        }
        let done = DispatchSemaphore(value: 0)
        let box = Box(settings.llm)
        Task.detached {
            var llm = box.value
            for p in ProviderID.allCases {
                for (i, k) in llm.keys(for: p).enumerated() {
                    guard let v = try? secrets.get(k.id), !v.isEmpty else {
                        print("\(p.displayName) ключ \(i + 1) ••••\(k.last4): нет значения в Связке ключей")
                        continue
                    }
                    let r = await verifier.verify(p, key: v, customBase: llm.customBase)
                    print("\(p.displayName) ключ \(i + 1) ••••\(k.last4): \(r.summary)")
                    guard let idx = llm.keys.firstIndex(where: { $0.id == k.id }) else { continue }
                    switch r {
                    case .ok(let models):
                        llm.keys[idx].invalid = false
                        llm.keys[idx].invalidReason = nil
                        llm.knownModels[p] = models
                        llm.knownModelsAt[p] = Date()
                        if i == 0 || showAll { print("  models: " + models.joined(separator: ", ")) }
                    case .invalidKey(let s, _):
                        llm.keys[idx].invalid = true
                        llm.keys[idx].invalidReason = "HTTP \(s)"
                    case .failed: break
                    }
                }
            }
            for e in llm.chain {
                let known = llm.knownModels[e.provider] ?? []
                let mark = known.isEmpty ? "?" : (known.contains(e.model) ? "ok" : "НЕТ В СПИСКЕ")
                print("chain: \(e.enabled ? "on " : "off") \(e.provider.displayName) \(e.model) [\(mark)]")
            }
            box.value = llm
            done.signal()
        }
        while done.wait(timeout: .now() + 0.05) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        settings.llm = box.value
        store.save(settings)
        return 0
    }
}

extension Headless {
    /// `Lingo --eval-dialog <кейсы> <выход> [--models m1,m2] [--only id1,id2]` (P-05): ключ — первый действующий ключ провайдера
    /// из Связки ключей. Модели — параллельно (лимиты Groq считаются на модель), кейсы — по одному.
    static func evalDialog(args: [String]) -> Int32 {
        guard let i = args.firstIndex(of: "--eval-dialog"), i + 2 < args.count else { print("usage: --eval-dialog <cases> <out>"); return 2 }
        let casesDir = URL(fileURLWithPath: args[i + 1]), outDir = URL(fileURLWithPath: args[i + 2])
        func opt(_ k: String) -> [String]? {
            guard let j = args.firstIndex(of: k), j + 1 < args.count else { return nil }
            return args[j + 1].split(separator: ",").map(String.init)
        }
        let settings = SettingsStore().load().llm
        let models = opt("--models") ?? settings.chain.filter { $0.enabled && $0.provider == .groq }.map(\.model)
        let provider: ProviderID = ProviderID(rawValue: opt("--provider")?.first ?? "groq") ?? .groq
        var cases: [DialogCase]
        do { cases = try DialogCase.load(dir: casesDir) } catch { print("cases: \(error)"); return 2 }
        if let only = opt("--only") { cases = cases.filter { only.contains($0.id) } }
        guard let rec = settings.keys(for: provider).first(where: { !$0.invalid }) else { print("нет действующего ключа \(provider.displayName)"); return 1 }
        let selected = cases, base = settings.customBase
        let done = DispatchSemaphore(value: 0)
        let box = Box(Int32(0))
        Task.detached {
            guard let key = try? KeychainStore().get(rec.id), !key.isEmpty else { print("ключ не прочитан из Связки ключей"); box.value = 1; done.signal(); return }
            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            print("eval dialog: \(selected.count) кейсов × \(models.count) моделей (\(provider.displayName), ключ ••••\(rec.last4))")
            let reports = await withTaskGroup(of: DialogRunner.Report.self) { g in
                for m in models {
                    g.addTask {
                        let p = OpenAICompatibleProvider(provider, customBase: base)
                        return await DialogRunner(provider: p, model: m, key: key).run(selected)
                    }
                }
                var out: [DialogRunner.Report] = []
                for await r in g { out.append(r) }
                return out
            }
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            enc.dateEncodingStrategy = .iso8601
            var summary: [String] = []
            for r in reports.sorted(by: { $0.model < $1.model }) {
                let name = "dialog-" + r.model.replacingOccurrences(of: "/", with: "_") + ".json"
                try? enc.encode(r).write(to: outDir.appendingPathComponent(name))
                let v = DialogRunner.verdict(r)
                summary += v.lines
                let explain = r.categoryRates["explain"].map { String(format: "%.0f%%", $0 * 100) } ?? "—"
                let ruu = r.categoryRates["ru_utterance"].map { String(format: "%.0f%%", $0 * 100) } ?? "—"
                summary.append("  AC-05: explain \(explain), ru_utterance \(ruu), lang_discipline \(String(format: "%.0f%%", (r.ruleRates["lang_discipline"] ?? 0) * 100))")
                let corr = ["correction_inline", "correction_after", "correction_on_demand"].map { k in "\(k) " + (r.categoryRates[k].map { String(format: "%.0f%%", $0 * 100) } ?? "—") }
                summary.append("  AC-06: " + corr.joined(separator: ", "))
                summary.append("  категории: " + r.categoryRates.sorted { $0.key < $1.key }.map { "\($0.key) \(String(format: "%.0f%%", $0.value * 100))" }.joined(separator: ", "))
                summary.append("  итог: \(v.pass ? "PASS" : "FAIL")")
            }
            let text = summary.joined(separator: "\n")
            try? text.write(to: outDir.appendingPathComponent("dialog-summary.txt"), atomically: true, encoding: .utf8)
            print(text)
            done.signal()
        }
        while done.wait(timeout: .now() + 0.05) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        return box.value
    }
}

final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ v: T) { value = v }
}
