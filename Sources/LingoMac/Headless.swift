import Foundation
import LingoCore
import LingoEvalKit

/// Service modes without a window. They print only metadata (provider, key index, last 4 characters, models).
@MainActor
enum Headless {
    static func checkKeys(showAll: Bool) -> Int32 {
        let store = SettingsStore()
        var settings = store.load()
        let secrets = KeychainStore()
        let verifier = KeyVerifier()
        if settings.llm.keys.isEmpty {
            print("check-keys: no keys (Settings → Keys and models)")
            return 1
        }
        let done = DispatchSemaphore(value: 0)
        let box = Box(settings.llm)
        Task.detached {
            var llm = box.value
            for p in ProviderID.allCases {
                for (i, k) in llm.keys(for: p).enumerated() {
                    guard let v = try? secrets.get(k.id), !v.isEmpty else {
                        print("\(p.displayName) key \(i + 1) ••••\(k.last4): no value in the Keychain")
                        continue
                    }
                    let r = await verifier.verify(p, key: v, customBase: llm.customBase)
                    print("\(p.displayName) key \(i + 1) ••••\(k.last4): \(r.summary)")
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
                let mark = known.isEmpty ? "?" : (known.contains(e.model) ? "ok" : "NOT IN LIST")
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
    /// `Lingo --eval-dialog <cases> <out> [--models m1,m2] [--only id1,id2]` (P-05): the key is the provider's first working key
    /// from the Keychain. Models run in parallel (Groq limits are per model), cases one at a time.
    static func evalDialog(args: [String]) -> Int32 {
        guard let i = args.firstIndex(of: "--eval-dialog"), i + 2 < args.count else { print("usage: --eval-dialog <cases> <out>"); return 2 }
        let casesDir = URL(fileURLWithPath: args[i + 1]), outDir = URL(fileURLWithPath: args[i + 2])
        func opt(_ k: String) -> [String]? {
            guard let j = args.firstIndex(of: k), j + 1 < args.count else { return nil }
            return args[j + 1].split(separator: ",").map(String.init)
        }
        let settings = SettingsStore().load().llm
        // Quota protection (Q29, review F-01): by default one model, 10 cases, at night; in the daytime only with --allow-daytime.
        let hour = Calendar.current.component(.hour, from: Date())
        if (8..<23).contains(hour), !args.contains("--allow-daytime") {
            print("eval dialog: not run in the daytime — the Groq quota is shared with the owner's practice (Q29). At night (23:00–08:00) or with --allow-daytime.")
            return 3
        }
        let models = opt("--models") ?? Array(settings.chain.filter { $0.enabled && $0.provider == .groq }.map(\.model).prefix(1))
        let maxCases = opt("--max-cases").flatMap { Int($0[0]) } ?? 10
        let budget = opt("--budget").flatMap { Int($0[0]) } ?? (maxCases + maxCases / 2)
        let provider: ProviderID = ProviderID(rawValue: opt("--provider")?.first ?? "groq") ?? .groq
        var cases: [DialogCase]
        do { cases = try DialogCase.load(dir: casesDir) } catch { print("cases: \(error)"); return 2 }
        if let only = opt("--only") { cases = cases.filter { only.contains($0.id) } }
        if opt("--only") == nil, cases.count > maxCases {
            // A batch round-robin over categories: each category is represented while the limit allows.
            var byCat: [String: [DialogCase]] = [:]
            for c in cases { byCat[c.category, default: []].append(c) }
            let offset = opt("--offset").flatMap { Int($0[0]) } ?? 0
            var picked: [DialogCase] = []
            var round = offset
            while picked.count < maxCases, byCat.values.contains(where: { $0.count > round % max(1, $0.count) }) {
                for k in byCat.keys.sorted() where picked.count < maxCases {
                    let list = byCat[k]!
                    let c = list[round % list.count]
                    if !picked.contains(where: { $0.id == c.id }) { picked.append(c) }
                }
                round += 1
                if round > offset + 20 { break }
            }
            cases = picked
        }
        guard let rec = settings.keys(for: provider).first(where: { !$0.invalid }) else { print("no working key for \(provider.displayName)"); return 1 }
        let selected = cases, base = settings.customBase
        let done = DispatchSemaphore(value: 0)
        let box = Box(Int32(0))
        Task.detached {
            guard let key = try? KeychainStore().get(rec.id), !key.isEmpty else { print("could not read the key from the Keychain"); box.value = 1; done.signal(); return }
            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            print("eval dialog: \(selected.count) cases × \(models.count) models (\(provider.displayName), key ••••\(rec.last4)), budget \(budget) requests per model")
            let usage = UsageRecorder(dir: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Lingo/usage", isDirectory: true))
            let reports = await withTaskGroup(of: DialogRunner.Report.self) { g in
                for m in models {
                    g.addTask {
                        let p = OpenAICompatibleProvider(provider, customBase: base)
                        var runner = DialogRunner(provider: p, model: m, key: key, maxRequests: budget, usage: usage)
                        let enc = JSONEncoder()
                        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                        enc.dateEncodingStrategy = .iso8601
                        let file = outDir.appendingPathComponent("dialog-" + m.replacingOccurrences(of: "/", with: "_") + ".json")
                        runner.onProgress = { r in try? enc.encode(r).write(to: file) }
                        return await runner.run(selected)
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
                summary.append("  categories: " + r.categoryRates.sorted { $0.key < $1.key }.map { "\($0.key) \(String(format: "%.0f%%", $0.value * 100))" }.joined(separator: ", "))
                summary.append("  verdict: \(v.pass ? "PASS" : "FAIL")")
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
