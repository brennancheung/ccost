import Foundation
import CCostLib

struct CostService: Sendable {
    func fetchTodayCost() -> CostData {
        let db = CostDatabase()
        let scanner = FileScanner()
        let parser = Parser()

        let discovered = scanner.discoverFiles()
        let cached = db.getCachedFiles()
        let diff = scanner.diffFiles(discovered: discovered, cached: cached)

        let filesToProcess = diff.added + diff.changed
        let records = parser.parseFiles(filesToProcess)

        if !filesToProcess.isEmpty || !diff.removed.isEmpty {
            db.writeResults(files: filesToProcess, records: records, removedPaths: diff.removed)
        }

        let today = todayDateString()
        let summaries = db.queryDailySummaries(since: today)

        guard let summary = summaries.first else {
            return CostData(cost: 0, sessions: 0, inputTokens: 0, outputTokens: 0,
                            cacheCreationInputTokens: 0, cacheReadInputTokens: 0)
        }

        return CostData(
            cost: summary.cost,
            sessions: summary.sessions,
            inputTokens: summary.inputTokens,
            outputTokens: summary.outputTokens,
            cacheCreationInputTokens: summary.cacheCreationInputTokens,
            cacheReadInputTokens: summary.cacheReadInputTokens
        )
    }

    func fetchHistory(days: Int = 30) -> [CCostLib.DailySummary] {
        let db = CostDatabase()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let since = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return db.queryDailySummaries(since: formatter.string(from: since))
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
