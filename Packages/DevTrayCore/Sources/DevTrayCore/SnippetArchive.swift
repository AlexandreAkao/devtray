import Foundation

/// Pure, store-agnostic JSON codec for snippet export/import.
/// Uses a versioned envelope so the import side can dispatch on `version`
/// for future format migrations.
public enum SnippetArchive {
    public static let currentVersion = 1

    private struct Envelope: Codable {
        let version: Int
        let exportedAt: Date
        let snippets: [Snippet]
    }

    public static func encode(_ snippets: [Snippet], exportedAt: Date) throws -> Data {
        let envelope = Envelope(version: currentVersion, exportedAt: exportedAt, snippets: snippets)
        let encoder = JSONEncoder()
        // ISO8601 keeps the export human-readable, stable, and diffable.
        // It drops sub-second precision, which is fine: snippet timestamps
        // are display/sort values, not identity.
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    public static func decode(_ data: Data) throws -> [Snippet] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct VersionProbe: Codable { let version: Int }
        let probe: VersionProbe
        do {
            probe = try decoder.decode(VersionProbe.self, from: data)
        } catch {
            throw ToolError.parseFailure(
                reason: "Not a valid DevTray snippet export.",
                hint: error.localizedDescription)
        }

        guard probe.version == currentVersion else {
            throw ToolError.parseFailure(
                reason: "Unsupported export version \(probe.version).",
                hint: "Expected version \(currentVersion).")
        }

        do {
            return try decoder.decode(Envelope.self, from: data).snippets
        } catch {
            throw ToolError.parseFailure(
                reason: "Could not read snippets from export.",
                hint: error.localizedDescription)
        }
    }
}
