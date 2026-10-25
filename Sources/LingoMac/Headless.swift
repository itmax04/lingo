import Foundation
import LingoCore

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

final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ v: T) { value = v }
}
