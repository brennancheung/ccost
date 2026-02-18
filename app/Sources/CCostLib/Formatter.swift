import Foundation

public struct CostFormatter: Sendable {
    // ANSI color codes
    private static let reset = "\u{1B}[0m"
    private static let bold = "\u{1B}[1m"
    private static let dim = "\u{1B}[2m"
    private static let green = "\u{1B}[32m"
    private static let yellow = "\u{1B}[33m"
    private static let cyan = "\u{1B}[36m"
    private static let white = "\u{1B}[37m"

    private static let colDate = 12
    private static let colCost = 12
    private static let colInput = 10
    private static let colOutput = 10
    private static let colCacheW = 10
    private static let colCacheR = 10
    private static let colSessions = 10
    private static let separatorWidth = colDate + colCost + colInput + colOutput + colCacheW + colCacheR + colSessions + 12

    public init() {}

    public func formatTable(
        summaries: [DailySummary],
        processedCount: Int,
        cachedCount: Int,
        elapsedMs: Int
    ) -> String {
        guard !summaries.isEmpty else {
            return "\(Self.dim)No usage data found.\(Self.reset)"
        }

        var lines: [String] = [""]
        lines.append(headerLine())
        lines.append(separator())

        for s in summaries {
            lines.append(formatRow(s))
        }

        lines.append(separator())

        // Totals
        var totals = DailySummary(date: "TOTAL", cost: 0, inputTokens: 0, outputTokens: 0,
                                   cacheCreationInputTokens: 0, cacheReadInputTokens: 0, sessions: 0)
        for s in summaries {
            totals.cost += s.cost
            totals.inputTokens += s.inputTokens
            totals.outputTokens += s.outputTokens
            totals.cacheCreationInputTokens += s.cacheCreationInputTokens
            totals.cacheReadInputTokens += s.cacheReadInputTokens
            totals.sessions += s.sessions
        }

        lines.append(
            "\(Self.bold)\(Self.white)\(pad("TOTAL", Self.colDate, .left))\(Self.reset)"
            + "  \(Self.cyan)\(pad(formatTokens(totals.inputTokens), Self.colInput, .right))\(Self.reset)"
            + "  \(Self.cyan)\(pad(formatTokens(totals.outputTokens), Self.colOutput, .right))\(Self.reset)"
            + "  \(Self.yellow)\(pad(formatTokens(totals.cacheCreationInputTokens), Self.colCacheW, .right))\(Self.reset)"
            + "  \(Self.yellow)\(pad(formatTokens(totals.cacheReadInputTokens), Self.colCacheR, .right))\(Self.reset)"
            + "  \(Self.green)\(Self.bold)\(pad(formatCost(totals.cost), Self.colCost, .right))\(Self.reset)"
            + "  \(Self.dim)\(pad("\(totals.sessions)", Self.colSessions, .right))\(Self.reset)"
        )

        lines.append(separator())
        lines.append(headerLine())

        let statsMsg = processedCount > 0
            ? "\(processedCount) files processed (\(cachedCount) cached)"
            : "\(cachedCount) files (all cached)"
        lines.append("\(Self.dim)  \(statsMsg) in \(elapsedMs)ms\(Self.reset)")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    public func formatJson(_ summaries: [DailySummary]) -> String {
        struct JsonSummary: Codable {
            let date: String
            let cost: Double
            let inputTokens: Int
            let outputTokens: Int
            let cacheCreationInputTokens: Int
            let cacheReadInputTokens: Int
            let sessions: Int
        }

        let items = summaries.map { s in
            JsonSummary(
                date: s.date, cost: s.cost,
                inputTokens: s.inputTokens, outputTokens: s.outputTokens,
                cacheCreationInputTokens: s.cacheCreationInputTokens,
                cacheReadInputTokens: s.cacheReadInputTokens,
                sessions: s.sessions
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private func headerLine() -> String {
        "\(Self.dim)"
        + pad("Date", Self.colDate, .left)
        + "  " + pad("Input", Self.colInput, .right)
        + "  " + pad("Output", Self.colOutput, .right)
        + "  " + pad("Cache W", Self.colCacheW, .right)
        + "  " + pad("Cache R", Self.colCacheR, .right)
        + "  " + pad("Cost", Self.colCost, .right)
        + "  " + pad("Sessions", Self.colSessions, .right)
        + "\(Self.reset)"
    }

    private func separator() -> String {
        "\(Self.dim)\(String(repeating: "\u{2500}", count: Self.separatorWidth))\(Self.reset)"
    }

    private func formatRow(_ s: DailySummary) -> String {
        "\(Self.white)\(pad(s.date, Self.colDate, .left))\(Self.reset)"
        + "  \(Self.cyan)\(pad(formatTokens(s.inputTokens), Self.colInput, .right))\(Self.reset)"
        + "  \(Self.cyan)\(pad(formatTokens(s.outputTokens), Self.colOutput, .right))\(Self.reset)"
        + "  \(Self.yellow)\(pad(formatTokens(s.cacheCreationInputTokens), Self.colCacheW, .right))\(Self.reset)"
        + "  \(Self.yellow)\(pad(formatTokens(s.cacheReadInputTokens), Self.colCacheR, .right))\(Self.reset)"
        + "  \(Self.green)\(Self.bold)\(pad(formatCost(s.cost), Self.colCost, .right))\(Self.reset)"
        + "  \(Self.dim)\(pad("\(s.sessions)", Self.colSessions, .right))\(Self.reset)"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatCost(_ n: Double) -> String {
        String(format: "$%.2f", n)
    }

    private enum Alignment { case left, right }

    private func pad(_ s: String, _ width: Int, _ align: Alignment) -> String {
        let padding = max(0, width - s.count)
        if align == .left {
            return s + String(repeating: " ", count: padding)
        }
        return String(repeating: " ", count: padding) + s
    }
}
