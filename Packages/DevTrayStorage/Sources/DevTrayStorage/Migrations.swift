import GRDB

public enum Migrations {
    public static func register(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_tool_usage") { db in
            try db.execute(sql: """
                CREATE TABLE tool_usage (
                    tool_id TEXT NOT NULL,
                    used_at REAL NOT NULL
                );
            """)
            try db.execute(sql: """
                CREATE INDEX idx_tool_usage_tool_used
                ON tool_usage(tool_id, used_at DESC);
            """)
        }

        migrator.registerMigration("v2_snippets") { db in
            try db.execute(sql: """
                CREATE TABLE snippets (
                    id            TEXT PRIMARY KEY,
                    title         TEXT NOT NULL,
                    content       TEXT NOT NULL,
                    language      TEXT,
                    tags          TEXT NOT NULL DEFAULT '[]',
                    is_favorite   INTEGER NOT NULL DEFAULT 0,
                    created_at    REAL NOT NULL,
                    updated_at    REAL NOT NULL,
                    use_count     INTEGER NOT NULL DEFAULT 0,
                    last_used_at  REAL
                );
            """)
            try db.execute(sql: "CREATE INDEX idx_snippets_updated ON snippets(updated_at DESC);")
            try db.execute(sql: "CREATE INDEX idx_snippets_favorite ON snippets(is_favorite, updated_at DESC);")

            // FTS5 external-content table; GRDB generates the INSERT/UPDATE/DELETE
            // sync triggers and back-fills from existing rows (a no-op here).
            try db.create(virtualTable: "snippets_fts", using: FTS5()) { t in
                t.synchronize(withTable: "snippets")
                t.column("title")
                t.column("content")
                t.column("tags")
            }
        }
    }
}
