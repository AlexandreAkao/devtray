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
}
