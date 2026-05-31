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

/// **Production storage** — file-backed (not the macOS Keychain) under
/// `~/Library/Application Support/DevTray/storage/<account>.bin`.
///
/// Why not Keychain: macOS legacy Keychain binds each item's ACL to the writing
/// binary's code-signature (`CodeSignatureAclSubject` w/ `cdhash`). For unsigned
/// or ad-hoc-signed builds, every rebuild produces a new cdhash → previous
/// items become unreadable. The `kSecUseDataProtectionKeychain` flag needs an
/// `application-identifier` entitlement we don't have. File storage works
/// uniformly across unsigned dev, ad-hoc, and notarized Developer ID builds.
///
/// Security posture: each file is mode 0600 inside the user's home — equivalent
/// privacy to Keychain items for an unsandboxed app (the threat model is "casual
/// inspection by the user", not "OS-level isolation"). A motivated user can
/// always reset trial state by deleting the storage directory — this is
/// acceptable because trial bypass damages only revenue (not security).
public struct SystemKeychain: KeychainProtocol {
    public let service: String

    public init(service: String = "com.devtray.DevTrayApp.license") {
        self.service = service
    }

    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("DevTray", isDirectory: true)
            .appendingPathComponent(service, isDirectory: true)
    }

    private func fileURL(for account: String) -> URL {
        storageDirectory.appendingPathComponent("\(account).bin", isDirectory: false)
    }

    public func set(_ data: Data, account: String) throws {
        let dir = storageDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let url = fileURL(for: account)
        // Atomic write so a crash mid-write doesn't leave a half-formed file.
        try data.write(to: url, options: .atomic)
        // Restrict file to owner-only — same posture as a Keychain item.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func get(account: String) throws -> Data? {
        let url = fileURL(for: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func delete(account: String) throws {
        let url = fileURL(for: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
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
