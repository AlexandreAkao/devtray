import Foundation
import GRDB
import DevTrayCore
import os

public final class SQLiteSnippetStore: SnippetStore, @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let logger = Logger(subsystem: "com.devtray.app", category: "storage")

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public static func openDefault() throws -> SQLiteSnippetStore {
        let url = try DatabaseOpener.defaultURL()
        let queue = try DatabaseOpener.open(at: url)
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)
        try migrator.migrate(queue)
        return SQLiteSnippetStore(dbQueue: queue)
    }

    public func save(_ snippet: Snippet) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO snippets
                    (id, title, content, language, tags, is_favorite,
                     created_at, updated_at, use_count, last_used_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title,
                    content = excluded.content,
                    language = excluded.language,
                    tags = excluded.tags,
                    is_favorite = excluded.is_favorite,
                    updated_at = excluded.updated_at,
                    use_count = excluded.use_count,
                    last_used_at = excluded.last_used_at
            """, arguments: [
                snippet.id,
                snippet.title,
                snippet.content,
                snippet.language,
                SnippetTagCodec.encode(snippet.tags),
                snippet.isFavorite,
                snippet.createdAt.timeIntervalSince1970,
                snippet.updatedAt.timeIntervalSince1970,
                snippet.useCount,
                snippet.lastUsedAt?.timeIntervalSince1970
            ])
        }
    }

    public func delete(id: Snippet.ID) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM snippets WHERE id = ?", arguments: [id])
        }
    }

    public func all() async throws -> [Snippet] {
        try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM snippets ORDER BY updated_at DESC")
                .map(Self.snippet(from:))
        }
    }

    public func search(_ query: String) async throws -> [Snippet] {
        guard let match = FTSQuery.sanitize(query) else {
            return try await all()
        }
        return try await dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT snippets.*
                FROM snippets
                JOIN snippets_fts ON snippets_fts.rowid = snippets.rowid
                WHERE snippets_fts MATCH ?
                ORDER BY bm25(snippets_fts), snippets.updated_at DESC
            """, arguments: [match]).map(Self.snippet(from:))
        }
    }

    public func incrementUseCount(id: Snippet.ID) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: """
                UPDATE snippets
                SET use_count = use_count + 1, last_used_at = ?
                WHERE id = ?
            """, arguments: [Date().timeIntervalSince1970, id])
        }
    }

    private static func snippet(from row: Row) -> Snippet {
        Snippet(
            id: row["id"],
            title: row["title"],
            content: row["content"],
            language: row["language"],
            tags: SnippetTagCodec.decode(row["tags"]),
            isFavorite: row["is_favorite"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"]),
            useCount: row["use_count"],
            lastUsedAt: (row["last_used_at"] as Double?).map { Date(timeIntervalSince1970: $0) }
        )
    }
}
