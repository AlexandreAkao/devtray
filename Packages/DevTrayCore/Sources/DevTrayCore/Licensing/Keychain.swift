import Foundation
import Security

/// Abstraction over the macOS Keychain so LicenseStore + TrialTracker can be unit-tested
/// with an in-memory fake.
public protocol KeychainProtocol: Sendable {
    func set(_ data: Data, account: String) throws
    func get(account: String) throws -> Data?
    func delete(account: String) throws
}

public enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

/// Production wrapper around Security framework. Single service id; one item per account.
public struct SystemKeychain: KeychainProtocol {
    public let service: String

    public init(service: String = "com.devtray.DevTrayApp.license") {
        self.service = service
    }

    public func set(_ data: Data, account: String) throws {
        // SecItemUpdate would be more efficient but SecItemAdd + fallback-on-duplicate is simpler.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
            return
        }
        throw KeychainError.unexpectedStatus(updateStatus)
    }

    public func get(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        return result as? Data
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

/// In-memory fake for unit tests. Thread-safe via NSLock.
public final class InMemoryKeychain: KeychainProtocol, @unchecked Sendable {
    private var store: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func set(_ data: Data, account: String) throws {
        lock.lock(); defer { lock.unlock() }
        store[account] = data
    }

    public func get(account: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return store[account]
    }

    public func delete(account: String) throws {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: account)
    }
}
