import Foundation
import GRDB
import os

public enum DatabaseOpener {
    public static func defaultURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("DevTray", isDirectory: true)
            .appendingPathComponent("devtray.sqlite")
    }

    public static func open(at url: URL) throws -> DatabaseQueue {
        let logger = Logger(subsystem: "com.devtray.app", category: "storage")
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        do {
            return try DatabaseQueue(path: url.path)
        } catch {
            logger.error("opening \(url.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")

            // Rename and retry once.
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let renamed = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).corrupted-\(stamp)")
            try FileManager.default.moveItem(at: url, to: renamed)
            logger.notice("renamed corrupt database to \(renamed.path, privacy: .public)")
            return try DatabaseQueue(path: url.path)
        }
    }
}
