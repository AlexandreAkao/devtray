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
    }
}
