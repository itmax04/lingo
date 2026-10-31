// Ported from Interview Copilot (`Sources/CopilotCore/Secrets/KeychainStore.swift`, commit cf0e764) and adapted:
// service `com.itmax04.lingo`, account — the key id (any number of keys per provider, R-29, Q13).
import Foundation
import Security

/// API key store (R-48). A key value is never logged and never returned to the UI after it is saved.
public protocol SecretStore: Sendable {
    func set(_ value: String, for id: String, label: String) throws
    func get(_ id: String) throws -> String?
    func delete(_ id: String) throws
    func contains(_ id: String) -> Bool
}

public enum SecretStoreError: Error, Equatable, CustomStringConvertible {
    case emptyValue
    case keychain(OSStatus)

    public var description: String {
        switch self {
        case .emptyValue:
            return String(localized: "Empty key")
        case .keychain(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain: \(message)"
        }
    }
}

/// Keychain: `kSecClassGenericPassword`, service `com.itmax04.lingo`, account = key id.
/// Works on iOS too (shared core).
public struct KeychainStore: SecretStore {
    public static let defaultService = "com.itmax04.lingo"
    public let service: String

    public init(service: String = KeychainStore.defaultService) {
        self.service = service
    }

    private func baseQuery(_ id: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
    }

    public func set(_ value: String, for id: String, label: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SecretStoreError.emptyValue }
        let data = Data(trimmed.utf8)
        var status = SecItemUpdate(baseQuery(id) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery(id)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            add[kSecAttrLabel as String] = "Lingo — \(label)"
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SecretStoreError.keychain(status) }
    }

    public func get(_ id: String) throws -> String? {
        var query = baseQuery(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecretStoreError.keychain(status) }
        return String(data: data, encoding: .utf8)
    }

    public func delete(_ id: String) throws {
        let status = SecItemDelete(baseQuery(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretStoreError.keychain(status) }
    }

    /// Whether a key exists — without reading the value (does not trigger an access prompt).
    public func contains(_ id: String) -> Bool {
        var query = baseQuery(id)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

/// In-memory store for tests, UI snapshots and evals with synthetic keys.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var values: [String: String] = [:]
    private let lock = NSLock()

    public init(_ initial: [String: String] = [:]) { values = initial }

    public func set(_ value: String, for id: String, label: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SecretStoreError.emptyValue }
        lock.withLock { values[id] = trimmed }
    }

    public func get(_ id: String) throws -> String? { lock.withLock { values[id] } }
    public func delete(_ id: String) throws { lock.withLock { values[id] = nil } }
    public func contains(_ id: String) -> Bool { lock.withLock { values[id] != nil } }
}
