import Foundation
import CryptoKit
import IOKit

public enum MachineIdentifierError: Error, Equatable {
    case unavailable  // IOKit query returned nil or threw
}

/// Injectable IOPlatformUUID reader. Production uses `IOKitMachineIDProvider`;
/// tests inject a stub. Defined as a protocol to keep MachineIdentifier itself
/// testable without touching real IOKit (which is unavailable on CI runners).
public protocol MachineIDProvider: Sendable {
    func read() throws -> String
}

public struct IOKitMachineIDProvider: MachineIDProvider {
    public init() {}
    public func read() throws -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { throw MachineIdentifierError.unavailable }
        defer { IOObjectRelease(service) }
        guard let cf = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0),
              let str = cf.takeRetainedValue() as? String, !str.isEmpty
        else { throw MachineIdentifierError.unavailable }
        return str
    }
}

/// Computes a privacy-preserving machine fingerprint hash for backend calls.
public enum MachineIdentifier {
    /// SHA256("v1:" + licenseUUID.uuidString + ":" + raw_uuid) as lowercase hex (64 chars).
    /// The "v1:" salt prefix reserves changing the hashing later (e.g. for v2 licenses)
    /// without colliding with existing v1 records server-side.
    public static func hash(for licenseUUID: UUID, provider: MachineIDProvider = IOKitMachineIDProvider()) throws -> String {
        let raw = try provider.read()
        let input = "v1:\(licenseUUID.uuidString):\(raw)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
