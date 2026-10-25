import AppKit
import LingoCore
import Observation

/// Ключи и цепочка (R-29, R-30, R-44, R-48). Значения ключей живут только в Keychain;
/// чтение — не на главном потоке (Keychain может ждать системного запроса доступа).
@MainActor
@Observable
final class KeysController {
    private(set) var settings: LLMSettings
    /// Результат последней проверки по id ключа (без значения ключа).
    var checks: [String: String] = [:]
    var busy: Set<String> = []
    var addError: [ProviderID: String] = [:]
    private let secrets: SecretStore
    private let verifier: KeyVerifier
    private let onChange: (LLMSettings) -> Void

    init(settings: LLMSettings, secrets: SecretStore, verifier: KeyVerifier = KeyVerifier(), onChange: @escaping (LLMSettings) -> Void) {
        self.settings = settings
        self.secrets = secrets
        self.verifier = verifier
        self.onChange = onChange
    }

    func update(_ f: (inout LLMSettings) -> Void) {
        f(&settings)
        onChange(settings)
    }

    // MARK: Ключи

    /// Сохраняет ключ в Keychain и сразу проверяет его. Поле ввода очищается вызывающим.
    func addKey(_ provider: ProviderID, value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard v.count >= 8 else { addError[provider] = "Ключ слишком короткий"; return }
        let rec = KeyRecord(provider: provider, last4: KeyRecord.last4(of: v))
        let n = settings.keys(for: provider).count + 1
        do {
            try secrets.set(v, for: rec.id, label: "\(provider.displayName) ключ \(n)")
        } catch {
            addError[provider] = "\(error)"
            return
        }
        addError[provider] = nil
        update { $0.keys.append(rec) }
        Log.app.notice("key added provider=\(provider.rawValue, privacy: .public) n=\(n, privacy: .public)")
        verify(rec.id)
    }

    func delete(_ id: String) {
        try? secrets.delete(id)
        update { $0.keys.removeAll { $0.id == id } }
        checks[id] = nil
    }

    /// «Проверить» (R-30): `GET /models`; ключ включается или выключается по результату, список моделей сохраняется.
    func verify(_ id: String) {
        guard let rec = settings.keys.first(where: { $0.id == id }) else { return }
        busy.insert(id)
        checks[id] = "Проверяю…"
        let secrets = self.secrets, verifier = self.verifier, base = settings.customBase
        Task {
            let result = await Task.detached { () -> KeyCheckResult in
                guard let value = try? secrets.get(id), !value.isEmpty else { return .failed(message: "ключ не найден в Связке ключей") }
                return await verifier.verify(rec.provider, key: value, customBase: base)
            }.value
            busy.remove(id)
            checks[id] = result.summary
            update { s in
                guard let i = s.keys.firstIndex(where: { $0.id == id }) else { return }
                switch result {
                case .ok(let models):
                    s.keys[i].invalid = false
                    s.keys[i].invalidReason = nil
                    s.knownModels[rec.provider] = models
                    s.knownModelsAt[rec.provider] = Date()
                case .invalidKey(let status, _):
                    s.keys[i].invalid = true
                    s.keys[i].invalidReason = "HTTP \(status)"
                case .failed:
                    break
                }
            }
        }
    }

    /// Цепочка сообщила, что ключ недействителен (R-29).
    func markInvalid(_ id: String, reason: String) {
        update { $0.markInvalid(keyID: id, reason: reason) }
    }

    // MARK: Цепочка

    func move(_ id: String, by delta: Int) {
        update { s in
            guard let i = s.chain.firstIndex(where: { $0.id == id }) else { return }
            let j = i + delta
            guard s.chain.indices.contains(j) else { return }
            s.chain.swapAt(i, j)
        }
    }

    func addStep(_ provider: ProviderID, model: String) {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        update { $0.chain.append(ChainEntry(provider: provider, model: m)) }
    }

    func removeStep(_ id: String) { update { $0.chain.removeAll { $0.id == id } } }

    func setEnabled(_ id: String, _ on: Bool) {
        update { s in if let i = s.chain.firstIndex(where: { $0.id == id }) { s.chain[i].enabled = on } }
    }

    func setModel(_ id: String, _ model: String) {
        update { s in if let i = s.chain.firstIndex(where: { $0.id == id }) { s.chain[i].model = model } }
    }

    func openKeysPage(_ p: ProviderID) {
        if let s = p.keysPage, let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }
}
