import AppKit

final class MenuBarContentView: NSView {
    private let costData: CostData?
    private let rateLimitData: RateLimitData?
    private let costError: String?
    private let rateLimitError: String?
    private let lastRefresh: Date?

    private let padding: CGFloat = 16
    private let sectionSpacing: CGFloat = 14
    private let lineSpacing: CGFloat = 4

    init(
        costData: CostData?,
        rateLimitData: RateLimitData?,
        costError: String?,
        rateLimitError: String?,
        lastRefresh: Date?
    ) {
        self.costData = costData
        self.rateLimitData = rateLimitData
        self.costError = costError
        self.rateLimitError = rateLimitError
        self.lastRefresh = lastRefresh
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 10))
        let height = layoutContent()
        self.frame = NSRect(x: 0, y: 0, width: 280, height: height)
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Layout

    private func layoutContent() -> CGFloat {
        var y: CGFloat = padding

        y = addCostSection(at: y)
        y += sectionSpacing
        y = addDivider(at: y)
        y += sectionSpacing
        y = addRateLimitSection(at: y)
        y += sectionSpacing
        y = addDivider(at: y)
        y += 10
        y = addLastRefresh(at: y)
        y += padding

        // Flip all subviews since NSView is bottom-up
        let totalHeight = y
        for sub in subviews {
            sub.frame.origin.y = totalHeight - sub.frame.origin.y - sub.frame.height
        }
        return totalHeight
    }

    // MARK: - Cost Section

    private func addCostSection(at startY: CGFloat) -> CGFloat {
        var y = startY

        if let err = costError {
            y = addLabel("Cost error: \(err)", at: y, font: .systemFont(ofSize: 12), color: .systemRed)
            return y
        }

        let cost = costData ?? CostData(cost: 0, sessions: 0, inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0)

        // "Today" header
        y = addLabel("Today", at: y, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabelColor)
        y += 2

        // Big cost number
        y = addLabel(Formatters.formatCost(cost.cost), at: y, font: .systemFont(ofSize: 28, weight: .semibold), color: .labelColor)
        y += 8

        // Stats grid
        let leftCol: [(String, String)] = [
            ("Sessions", "\(cost.sessions)"),
            ("Input", Formatters.formatTokens(cost.inputTokens)),
            ("Cache write", Formatters.formatTokens(cost.cacheCreationInputTokens)),
        ]
        let rightCol: [(String, String)] = [
            ("", ""),
            ("Output", Formatters.formatTokens(cost.outputTokens)),
            ("Cache read", Formatters.formatTokens(cost.cacheReadInputTokens)),
        ]

        let halfWidth = (frame.width - padding * 2 - 12) / 2
        for i in 0..<leftCol.count {
            let (lLabel, lValue) = leftCol[i]
            let (rLabel, rValue) = rightCol[i]

            guard !lLabel.isEmpty else { continue }

            let rowY = y
            addStatPair(lLabel, value: lValue, at: rowY, x: padding, width: halfWidth)
            if !rLabel.isEmpty {
                addStatPair(rLabel, value: rValue, at: rowY, x: padding + halfWidth + 12, width: halfWidth)
            }
            y += 18
        }

        return y
    }

    private func addStatPair(_ label: String, value: String, at y: CGFloat, x: CGFloat, width: CGFloat) {
        let labelField = makeTextField(label, font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
        labelField.frame = NSRect(x: x, y: y, width: width, height: 14)
        addSubview(labelField)

        let valueField = makeTextField(value, font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium), color: .labelColor)
        valueField.alignment = .right
        valueField.frame = NSRect(x: x, y: y, width: width, height: 14)
        addSubview(valueField)
    }

    // MARK: - Rate Limit Section

    private func addRateLimitSection(at startY: CGFloat) -> CGFloat {
        var y = startY

        if let err = rateLimitError {
            y = addLabel("Usage error: \(err)", at: y, font: .systemFont(ofSize: 12), color: .systemRed)
            return y
        }

        guard let rl = rateLimitData else {
            y = addLabel("Rate limits: loading...", at: y, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
            return y
        }

        y = addUsageWindow("5-hour window", utilization: rl.fiveHourUtilization, resetsAt: rl.fiveHourResetsAt, showProjection: false, at: y)
        y += sectionSpacing
        y = addUsageWindow("7-day window", utilization: rl.sevenDayUtilization, resetsAt: rl.sevenDayResetsAt, showProjection: true, at: y)

        return y
    }

    private func addUsageWindow(_ title: String, utilization: Double, resetsAt: Date?, showProjection: Bool, at startY: CGFloat) -> CGFloat {
        var y = startY
        let barWidth = frame.width - padding * 2

        let titleField = makeTextField(title, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabelColor)
        titleField.frame = NSRect(x: padding, y: y, width: barWidth * 0.6, height: 14)
        addSubview(titleField)

        let pctField = makeTextField(Formatters.formatPercent(utilization), font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold), color: colorForUtilization(utilization))
        pctField.alignment = .right
        pctField.frame = NSRect(x: padding, y: y, width: barWidth, height: 14)
        addSubview(pctField)
        y += 18

        let barHeight: CGFloat = 8
        let barView = MenuBarProgressBarView(utilization: utilization, frame: NSRect(x: padding, y: y, width: barWidth, height: barHeight))
        addSubview(barView)
        y += barHeight + 6

        guard let resetsAt else {
            y = addLabel("No reset scheduled", at: y, font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
            return y
        }

        let resetStr = "Resets in \(Formatters.formatTimeRemaining(until: resetsAt))"
        y = addLabel(resetStr, at: y, font: .systemFont(ofSize: 11), color: .secondaryLabelColor)

        guard showProjection else { return y }
        guard let projected = Formatters.projectedUsage(utilization: utilization, resetsAt: resetsAt) else { return y }
        let projStr = "Projected: \(Formatters.formatPercent(projected))"
        y = addLabel(projStr, at: y, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabelColor)

        return y
    }

    // MARK: - Last Refresh

    private func addLastRefresh(at y: CGFloat) -> CGFloat {
        let timeStr = lastRefresh.map { Formatters.formatTimestamp($0) } ?? "never"
        return addLabel("Last refresh: \(timeStr)", at: y, font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
    }

    // MARK: - Helpers

    private func addDivider(at y: CGFloat) -> CGFloat {
        let divider = NSBox(frame: NSRect(x: padding, y: y, width: frame.width - padding * 2, height: 1))
        divider.boxType = .separator
        addSubview(divider)
        return y + 1
    }

    @discardableResult
    private func addLabel(_ text: String, at y: CGFloat, font: NSFont, color: NSColor) -> CGFloat {
        let field = makeTextField(text, font: font, color: color)
        let size = field.sizeThatFits(NSSize(width: frame.width - padding * 2, height: .greatestFiniteMagnitude))
        field.frame = NSRect(x: padding, y: y, width: frame.width - padding * 2, height: size.height)
        addSubview(field)
        return y + size.height + lineSpacing
    }

    private func makeTextField(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.backgroundColor = .clear
        return field
    }

    private func colorForUtilization(_ pct: Double) -> NSColor {
        guard pct < 60 else {
            guard pct < 85 else { return .secondaryLabelColor }
            return .secondaryLabelColor
        }
        return .labelColor
    }

    override func mouseUp(with event: NSEvent) {
        // Swallow clicks so the menu doesn't close
    }
}

// MARK: - Menu Bar Progress Bar

private final class MenuBarProgressBarView: NSView {
    private let utilization: Double

    init(utilization: Double, frame: NSRect) {
        self.utilization = utilization
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let radius: CGFloat = bounds.height / 2

        // Track background
        let trackPath = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor.separatorColor.withAlphaComponent(0.3).setFill()
        trackPath.fill()

        // Track border
        let insetRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let borderPath = NSBezierPath(roundedRect: insetRect, xRadius: radius, yRadius: radius)
        borderPath.lineWidth = 1
        NSColor.separatorColor.setStroke()
        borderPath.stroke()

        // Fill
        let fillWidth = max(0, min(bounds.width, bounds.width * CGFloat(utilization / 100.0)))
        guard fillWidth > 0 else { return }
        let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: bounds.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
        fillColor().setFill()
        fillPath.fill()
    }

    private func fillColor() -> NSColor {
        guard utilization < 60 else {
            guard utilization < 85 else { return NSColor(calibratedRed: 0.75, green: 0.22, blue: 0.17, alpha: 0.8) }
            return NSColor(calibratedRed: 0.80, green: 0.55, blue: 0.15, alpha: 0.8)
        }
        return NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.75, alpha: 0.8)
    }
}
