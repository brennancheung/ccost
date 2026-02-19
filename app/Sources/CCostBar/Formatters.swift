import Foundation

enum Formatters {
    private static let costFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func formatCost(_ cost: Double) -> String {
        let numStr = costFormatter.string(from: NSNumber(value: cost)) ?? String(format: "%.2f", cost)
        return "$\(numStr)"
    }

    static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func formatTokens(_ count: Int) -> String {
        guard count >= 1000 else { return "\(count)" }
        guard count >= 1_000_000 else {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return String(format: "%.1fM", Double(count) / 1_000_000.0)
    }

    static func formatTimeRemaining(until date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        guard days > 0 else {
            guard hours > 0 else { return "\(minutes)m" }
            return "\(hours)h \(minutes)m"
        }
        return "\(days)d \(hours)h"
    }

    static func progressBar(_ percent: Double, width: Int = 20) -> String {
        let filled = Int((percent / 100.0) * Double(width))
        let clamped = max(0, min(width, filled))
        let filledStr = String(repeating: "\u{2588}", count: clamped)
        let emptyStr = String(repeating: "\u{2591}", count: width - clamped)
        return filledStr + emptyStr
    }

    static func formatMenuBar(cost: Double?, rateLimits: RateLimitData?, format: DisplayFormat) -> String {
        let costStr = formatCost(cost ?? 0)
        let percentStr = formatPercent(rateLimits?.sevenDayUtilization ?? 0)
        let compactCost = String(format: "%.2f", cost ?? 0)
        let compactPercent = String(format: "%.0f", rateLimits?.sevenDayUtilization ?? 0)

        let formatMap: [DisplayFormat: String] = [
            .costAndPercent: "\(costStr) \u{00B7} \(percentStr)",
            .costOnly: costStr,
            .percentOnly: percentStr,
            .compact: "\(compactCost)/\(compactPercent)",
        ]
        return formatMap[format] ?? costStr
    }

    static func displayFormatLabel(_ format: DisplayFormat) -> String {
        let labels: [DisplayFormat: String] = [
            .costAndPercent: "$12.50 \u{00B7} 45%",
            .costOnly: "$12.50",
            .percentOnly: "45%",
            .compact: "12.50/45",
        ]
        return labels[format] ?? ""
    }

    static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func hotKeyComboLabel(_ combo: HotKeyCombo) -> String {
        let labels: [HotKeyCombo: String] = [
            .ctrlShiftC: "⌃⇧C",
            .optionShiftC: "⌥⇧C",
            .ctrlOptionC: "⌃⌥C",
            .disabled: "Disabled",
        ]
        return labels[combo] ?? ""
    }

    static func projectedUsage(utilization: Double, resetsAt: Date) -> Double? {
        let totalSeconds = 7.0 * 24 * 3600
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        let elapsed = totalSeconds - remaining
        guard elapsed > 3600 else { return nil }
        return (utilization / elapsed) * totalSeconds
    }
}
