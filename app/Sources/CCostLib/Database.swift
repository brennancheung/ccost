import Foundation
import SQLite3

public final class CostDatabase {
    private var db: OpaquePointer?
    private let dbPath: String

    public init() {
        let cacheDir = NSHomeDirectory() + "/.cache/ccost"
        self.dbPath = cacheDir + "/cache.db"

        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDir) {
            try? fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        }

        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            fatalError("Failed to open database at \(dbPath)")
        }

        exec("PRAGMA journal_mode = WAL")
        exec("PRAGMA synchronous = NORMAL")

        exec("""
            CREATE TABLE IF NOT EXISTS files (
                file_path TEXT PRIMARY KEY,
                mtime_ms INTEGER NOT NULL,
                size INTEGER NOT NULL,
                session_id TEXT NOT NULL,
                project_dir TEXT NOT NULL
            )
        """)

        exec("""
            CREATE TABLE IF NOT EXISTS usage (
                file_path TEXT NOT NULL,
                date TEXT NOT NULL,
                model TEXT NOT NULL,
                session_id TEXT NOT NULL,
                project_dir TEXT NOT NULL,
                input_tokens INTEGER DEFAULT 0,
                output_tokens INTEGER DEFAULT 0,
                cache_creation_input_tokens INTEGER DEFAULT 0,
                cache_read_input_tokens INTEGER DEFAULT 0,
                message_count INTEGER DEFAULT 0,
                PRIMARY KEY (file_path, date, model)
            )
        """)

        exec("CREATE INDEX IF NOT EXISTS idx_usage_date ON usage(date)")
    }

    deinit {
        sqlite3_close(db)
    }

    public func getCachedFiles() -> [String: (mtimeMs: Int, size: Int)] {
        var result: [String: (mtimeMs: Int, size: Int)] = [:]
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT file_path, mtime_ms, size FROM files", -1, &stmt, nil) == SQLITE_OK else {
            return result
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let pathPtr = sqlite3_column_text(stmt, 0) else { continue }
            let path = String(cString: pathPtr)
            let mtimeMs = Int(sqlite3_column_int64(stmt, 1))
            let size = Int(sqlite3_column_int64(stmt, 2))
            result[path] = (mtimeMs: mtimeMs, size: size)
        }

        return result
    }

    public func writeResults(files: [FileInfo], records: [UsageRecord], removedPaths: [String]) {
        exec("BEGIN TRANSACTION")

        // Remove stale entries
        for path in removedPaths {
            execBind("DELETE FROM files WHERE file_path = ?", path)
            execBind("DELETE FROM usage WHERE file_path = ?", path)
        }

        // Remove changed files' old data
        for file in files {
            execBind("DELETE FROM files WHERE file_path = ?", file.filePath)
            execBind("DELETE FROM usage WHERE file_path = ?", file.filePath)
        }

        // Insert file metadata
        var insertFileStmt: OpaquePointer?
        let insertFileSQL = "INSERT INTO files (file_path, mtime_ms, size, session_id, project_dir) VALUES (?, ?, ?, ?, ?)"
        guard sqlite3_prepare_v2(db, insertFileSQL, -1, &insertFileStmt, nil) == SQLITE_OK else {
            exec("ROLLBACK")
            return
        }

        for file in files {
            sqlite3_reset(insertFileStmt)
            sqlite3_bind_text(insertFileStmt, 1, file.filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(insertFileStmt, 2, Int64(file.mtimeMs))
            sqlite3_bind_int64(insertFileStmt, 3, Int64(file.size))
            sqlite3_bind_text(insertFileStmt, 4, file.sessionId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertFileStmt, 5, file.projectDir, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(insertFileStmt)
        }
        sqlite3_finalize(insertFileStmt)

        // Insert usage records
        var insertUsageStmt: OpaquePointer?
        let insertUsageSQL = """
            INSERT INTO usage (file_path, date, model, session_id, project_dir, input_tokens, output_tokens,
                cache_creation_input_tokens, cache_read_input_tokens, message_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        guard sqlite3_prepare_v2(db, insertUsageSQL, -1, &insertUsageStmt, nil) == SQLITE_OK else {
            exec("ROLLBACK")
            return
        }

        for r in records {
            sqlite3_reset(insertUsageStmt)
            sqlite3_bind_text(insertUsageStmt, 1, r.filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertUsageStmt, 2, r.date, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertUsageStmt, 3, r.model, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertUsageStmt, 4, r.sessionId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertUsageStmt, 5, r.projectDir, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(insertUsageStmt, 6, Int64(r.inputTokens))
            sqlite3_bind_int64(insertUsageStmt, 7, Int64(r.outputTokens))
            sqlite3_bind_int64(insertUsageStmt, 8, Int64(r.cacheCreationInputTokens))
            sqlite3_bind_int64(insertUsageStmt, 9, Int64(r.cacheReadInputTokens))
            sqlite3_bind_int64(insertUsageStmt, 10, Int64(r.messageCount))
            sqlite3_step(insertUsageStmt)
        }
        sqlite3_finalize(insertUsageStmt)

        exec("COMMIT")
    }

    public func queryDailySummaries(since: String? = nil, until: String? = nil, project: String? = nil) -> [DailySummary] {
        var conditions: [String] = []
        var params: [String] = []

        if let since {
            conditions.append("date >= ?")
            params.append(since)
        }
        if let until {
            conditions.append("date <= ?")
            params.append(until)
        }
        if let project {
            conditions.append("project_dir LIKE ?")
            params.append("%\(project)%")
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"

        // Query usage grouped by date + model for per-model cost calculation
        let sql = """
            SELECT date, model,
                SUM(input_tokens) as input_tokens,
                SUM(output_tokens) as output_tokens,
                SUM(cache_creation_input_tokens) as cache_creation_input_tokens,
                SUM(cache_read_input_tokens) as cache_read_input_tokens
            FROM usage
            \(whereClause)
            GROUP BY date, model
            ORDER BY date DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }

        var dayMap: [String: DailySummary] = [:]

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let datePtr = sqlite3_column_text(stmt, 0),
                  let modelPtr = sqlite3_column_text(stmt, 1) else { continue }

            let date = String(cString: datePtr)
            let model = String(cString: modelPtr)
            let inputTokens = Int(sqlite3_column_int64(stmt, 2))
            let outputTokens = Int(sqlite3_column_int64(stmt, 3))
            let cacheCreation = Int(sqlite3_column_int64(stmt, 4))
            let cacheRead = Int(sqlite3_column_int64(stmt, 5))

            let cost = Pricing.shared.calculateCost(
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationInputTokens: cacheCreation,
                cacheReadInputTokens: cacheRead
            )

            if var existing = dayMap[date] {
                existing.cost += cost
                existing.inputTokens += inputTokens
                existing.outputTokens += outputTokens
                existing.cacheCreationInputTokens += cacheCreation
                existing.cacheReadInputTokens += cacheRead
                dayMap[date] = existing
            } else {
                dayMap[date] = DailySummary(
                    date: date,
                    cost: cost,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationInputTokens: cacheCreation,
                    cacheReadInputTokens: cacheRead,
                    sessions: 0
                )
            }
        }

        // Get true distinct session counts per day
        let sessionSQL = """
            SELECT date, COUNT(DISTINCT session_id) as sessions
            FROM usage
            \(whereClause)
            GROUP BY date
        """

        var sessionStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sessionSQL, -1, &sessionStmt, nil) == SQLITE_OK {
            for (i, param) in params.enumerated() {
                sqlite3_bind_text(sessionStmt, Int32(i + 1), param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }

            while sqlite3_step(sessionStmt) == SQLITE_ROW {
                guard let datePtr = sqlite3_column_text(sessionStmt, 0) else { continue }
                let date = String(cString: datePtr)
                let sessions = Int(sqlite3_column_int64(sessionStmt, 1))
                dayMap[date]?.sessions = sessions
            }
            sqlite3_finalize(sessionStmt)
        }

        return dayMap.values.sorted { $0.date < $1.date }
    }

    public func clearCache() {
        exec("DELETE FROM files")
        exec("DELETE FROM usage")
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func execBind(_ sql: String, _ param: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
}
