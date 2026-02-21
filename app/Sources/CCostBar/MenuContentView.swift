import AppKit

final class MenuContentView: NSView {
    private let costData: CostData?
    private let rateLimitData: RateLimitData?
    private let costError: String?
    private let rateLimitError: String?
    private let lastRefresh: Date?

    private let padding: CGFloat = 12
    private let cardPadding: CGFloat = 12
    private let sectionSpacing: CGFloat = 20
    private let lineSpacing: CGFloat = 4

    private var isWideLayout: Bool { frame.width > 400 }

    init(
        costData: CostData?,
        rateLimitData: RateLimitData?,
        costError: String?,
        rateLimitError: String?,
        lastRefresh: Date?,
        width: CGFloat = 280
    ) {
        self.costData = costData
        self.rateLimitData = rateLimitData
        self.costError = costError
        self.rateLimitError = rateLimitError
        self.lastRefresh = lastRefresh
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        wantsLayer = true
        let height = layoutContent()
        self.frame = NSRect(x: 0, y: 0, width: width, height: height)
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Layout

    private func layoutContent() -> CGFloat {
        var y: CGFloat = padding

        y = addCostCard(at: y)
        y += sectionSpacing
        y = addWeeklyUsageCard(at: y)

        let totalHeight = y
        for sub in subviews {
            sub.frame.origin.y = totalHeight - sub.frame.origin.y - sub.frame.height
        }
        return totalHeight
    }

    // MARK: - Cost Card (Today's Spend + Gauge)

    private func addCostCard(at startY: CGFloat) -> CGFloat {
        let cardX = padding
        let cardWidth = frame.width - padding * 2

        var y = startY + cardPadding

        if let err = costError {
            y = addLabel("Cost error: \(err)", at: y, font: Theme.font(ofSize: 12), color: Theme.errorRed, inset: cardX + cardPadding)
            let cardHeight = y - startY + cardPadding
            addCardBackground(at: startY, x: cardX, width: cardWidth, height: cardHeight)
            return startY + cardHeight
        }

        let cost = costData ?? CostData(cost: 0, sessions: 0, inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0)

        let contentLeft = cardX + cardPadding
        let contentWidth = cardWidth - cardPadding * 2

        // "TODAY'S SPEND" header
        y += 32
        y = addLabel("TODAY'S SPEND", at: y, font: Theme.font(ofSize: 13, weight: .bold), color: Theme.textAccent, inset: contentLeft + 12)

        // Big cost number
        let costWeight: NSFont.Weight = isWideLayout ? .semibold : .bold
        y = addLabel(Formatters.formatCost(cost.cost), at: y, font: Theme.font(ofSize: 40, weight: costWeight), color: Theme.textPrimary, inset: contentLeft + 12)
        y += 4

        let rl = rateLimitData

        if isWideLayout {
            let statsX: CGFloat = contentLeft + 180
            let statsY: CGFloat = startY + 32
            let statsWidth = contentWidth * 0.50
            addStatsGrid(cost, at: statsY, x: statsX, width: statsWidth - 8)

            if let rl {
                let gaugeSize: CGFloat = 140
                let gaugeX = contentLeft + contentWidth - gaugeSize + 8
                let gaugeY = startY + cardPadding - 4
                let gaugeView = CircularGaugeView(
                    utilization: rl.fiveHourUtilization,
                    resetsAt: rl.fiveHourResetsAt,
                    frame: NSRect(x: gaugeX, y: gaugeY, width: gaugeSize, height: gaugeSize)
                )
                addSubview(gaugeView)
            }

            let cardHeight: CGFloat = 150
            addCardBackground(at: startY, x: cardX, width: cardWidth, height: cardHeight)
            return startY + cardHeight
        } else {
            y = addStatsGrid(cost, at: y, x: contentLeft, width: contentWidth)
            y += 6

            if let rl {
                let narrowGaugeSize: CGFloat = 100
                let gaugeView = CircularGaugeView(
                    utilization: rl.fiveHourUtilization,
                    resetsAt: rl.fiveHourResetsAt,
                    frame: NSRect(x: contentLeft + (contentWidth - narrowGaugeSize) / 2, y: y, width: narrowGaugeSize, height: narrowGaugeSize)
                )
                addSubview(gaugeView)
                y += narrowGaugeSize + 4
            }

            y += cardPadding
            let cardHeight = y - startY
            addCardBackground(at: startY, x: cardX, width: cardWidth, height: cardHeight)
            return y
        }
    }

    private func addStatsGrid(_ cost: CostData, at startY: CGFloat, x: CGFloat, width: CGFloat) -> CGFloat {
        var y = startY
        let colGap: CGFloat = 6
        let colWidth = (width - colGap * 2) / 3

        let row1: [(String, String)] = [
            ("Sessions", "\(cost.sessions)"),
            ("Input", Formatters.formatTokens(cost.inputTokens)),
            ("Cache write", Formatters.formatTokens(cost.cacheCreationInputTokens)),
        ]
        let row2: [(String, String)] = [
            ("Cache write", Formatters.formatTokens(cost.cacheCreationInputTokens)),
            ("Output", Formatters.formatTokens(cost.outputTokens)),
            ("Cache read", Formatters.formatTokens(cost.cacheReadInputTokens)),
        ]

        for row in [row1, row2] {
            for (colIdx, pair) in row.enumerated() {
                let colX = x + CGFloat(colIdx) * (colWidth + colGap)
                addStackedStat(pair.0, value: pair.1, at: y, x: colX, width: colWidth)
            }
            y += 50
        }
        return y
    }

    private func addStackedStat(_ label: String, value: String, at y: CGFloat, x: CGFloat, width: CGFloat) {
        let labelField = makeTextField(label, font: Theme.font(ofSize: 11), color: Theme.textSecondary)
        labelField.frame = NSRect(x: x, y: y, width: width, height: 14)
        addSubview(labelField)

        let valueWeight: NSFont.Weight = isWideLayout ? .semibold : .bold
        let valueField = makeTextField(value, font: Theme.monospacedDigitFont(ofSize: 15, weight: valueWeight), color: Theme.textPrimary)
        valueField.frame = NSRect(x: x, y: y + 15, width: width, height: 18)
        addSubview(valueField)
    }

    // MARK: - Weekly Usage Card

    private func addWeeklyUsageCard(at startY: CGFloat) -> CGFloat {
        let cardX = padding
        let cardWidth = frame.width - padding * 2
        let contentLeft = cardX + cardPadding
        let contentWidth = cardWidth - cardPadding * 2
        let innerPad: CGFloat = isWideLayout ? 16 : cardPadding

        var y = startY + innerPad

        if let err = rateLimitError {
            y = addLabel("Usage error: \(err)", at: y, font: Theme.font(ofSize: 12), color: Theme.errorRed, inset: contentLeft)
            let cardHeight = y - startY + innerPad
            addCardBackground(at: startY, x: cardX, width: cardWidth, height: cardHeight)
            return startY + cardHeight
        }

        guard let rl = rateLimitData else {
            y = addLabel("Rate limits: loading...", at: y, font: Theme.font(ofSize: 11), color: Theme.textSecondary, inset: contentLeft)
            let cardHeight = y - startY + innerPad
            addCardBackground(at: startY, x: cardX, width: cardWidth, height: cardHeight)
            return startY + cardHeight
        }

        // Title: "WEEKLY USAGE" left, large percentage right
        let titleField = makeTextField("WEEKLY USAGE", font: Theme.font(ofSize: 13, weight: .medium), color: Theme.textPrimary)
        titleField.frame = NSRect(x: contentLeft, y: y, width: contentWidth * 0.6, height: 18)
        addSubview(titleField)

        let pctField = makeTextField(
            Formatters.formatPercent(rl.sevenDayUtilization),
            font: Theme.monospacedDigitFont(ofSize: 28, weight: .medium),
            color: Theme.textPrimary
        )
        pctField.alignment = .right
        pctField.frame = NSRect(x: contentLeft - 2, y: y + 2, width: contentWidth, height: 36)
        addSubview(pctField)
        y += isWideLayout ? 22 : 20

        // Subtitle: "7-day window"
        let subtitleField = makeTextField("7-day window", font: Theme.font(ofSize: 12), color: Theme.textSecondary)
        subtitleField.frame = NSRect(x: contentLeft, y: y, width: contentWidth * 0.6, height: 16)
        addSubview(subtitleField)
        y += isWideLayout ? 26 : 22

        // Progress bar
        let barHeight: CGFloat = isWideLayout ? 16 : 14
        let barView = ProgressBarView(utilization: rl.sevenDayUtilization, enhanced: isWideLayout, frame: NSRect(x: contentLeft, y: y, width: contentWidth, height: barHeight))
        addSubview(barView)
        y += barHeight + (isWideLayout ? 14 : 10)

        // Reset time (left) and Projected (right) on same line
        if let resetsAt = rl.sevenDayResetsAt {
            let resetStr = "Resets in \(Formatters.formatTimeRemaining(until: resetsAt))"
            let resetField = makeTextField(resetStr, font: Theme.font(ofSize: 11), color: Theme.textSecondary)
            resetField.frame = NSRect(x: contentLeft, y: y, width: contentWidth * 0.5, height: 16)
            addSubview(resetField)

            if let projected = Formatters.projectedUsage(utilization: rl.sevenDayUtilization, resetsAt: resetsAt) {
                let projStr = "Projected: \(Formatters.formatPercent(projected))"
                let projField = makeTextField(projStr, font: Theme.font(ofSize: 11, weight: .medium), color: Theme.textSecondary)
                projField.alignment = .right
                projField.frame = NSRect(x: contentLeft, y: y, width: contentWidth, height: 16)
                addSubview(projField)
            }
            y += isWideLayout ? 22 : 20
        } else {
            y = addLabel("No reset scheduled", at: y, font: Theme.font(ofSize: 11), color: Theme.textSecondary, inset: contentLeft)
        }

        y += innerPad
        let cardHeight = y - startY
        addCardBackground(at: startY, x: cardX, width: cardWidth, height: cardHeight)
        return y
    }

    // MARK: - Last Refresh

    private func addLastRefresh(at y: CGFloat) -> CGFloat {
        let timeStr = lastRefresh.map { Formatters.formatTimestamp($0) } ?? "never"
        return addLabel("Last refresh: \(timeStr)", at: y, font: Theme.font(ofSize: 9), color: Theme.textTertiary, inset: padding + 4)
    }

    // MARK: - Card Background

    private func addCardBackground(at y: CGFloat, x: CGFloat, width: CGFloat, height: CGFloat) {
        let cardBg = GradientCardView(frame: NSRect(x: x, y: y, width: width, height: height))
        addSubview(cardBg, positioned: .below, relativeTo: subviews.first)
    }

    // MARK: - Helpers

    @discardableResult
    private func addLabel(_ text: String, at y: CGFloat, font: NSFont, color: NSColor, inset: CGFloat) -> CGFloat {
        let field = makeTextField(text, font: font, color: color)
        let maxWidth = frame.width - inset - padding
        let size = field.sizeThatFits(NSSize(width: maxWidth, height: .greatestFiniteMagnitude))
        field.frame = NSRect(x: inset, y: y, width: maxWidth, height: size.height)
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

    override func mouseUp(with event: NSEvent) {
        // Swallow clicks so the menu doesn't close
    }
}

// MARK: - Progress Bar

final class ProgressBarView: NSView {
    private let utilization: Double
    private let enhanced: Bool

    init(utilization: Double, enhanced: Bool = false, frame: NSRect) {
        self.utilization = utilization
        self.enhanced = enhanced
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let radius: CGFloat = bounds.height / 2

        // Track background
        let trackPath = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor.white.withAlphaComponent(0.08).setFill()
        trackPath.fill()

        // Fill with gradient
        let fillWidth = max(0, min(bounds.width, bounds.width * CGFloat(utilization / 100.0)))
        guard fillWidth > 0 else { return }
        let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: bounds.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)

        let fillColors = [
            NSColor(srgbRed: 0.00, green: 0.85, blue: 1.0, alpha: 1),   // bright cyan
            NSColor(srgbRed: 0.20, green: 0.55, blue: 0.95, alpha: 1),  // mid blue
        ]

        // Glow layer (draw before fill for bloom effect)
        if enhanced {
            let ctx = NSGraphicsContext.current
            ctx?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(srgbRed: 0.10, green: 0.70, blue: 1.0, alpha: 0.9)
            shadow.shadowBlurRadius = 20
            shadow.shadowOffset = NSSize(width: 0, height: 0)
            shadow.set()
            if let gradient = NSGradient(colors: fillColors) {
                gradient.draw(in: fillPath, angle: 0)
            }
            ctx?.restoreGraphicsState()
        }

        // Fill on top (crisp)
        if let gradient = NSGradient(colors: fillColors) {
            gradient.draw(in: fillPath, angle: 0)
        }

        // White border around the filled portion
        if enhanced {
            let strokeInset = fillRect.insetBy(dx: 0.5, dy: 0.5)
            let strokePath = NSBezierPath(roundedRect: strokeInset, xRadius: radius, yRadius: radius)
            strokePath.lineWidth = 1.0
            NSColor.white.withAlphaComponent(0.35).setStroke()
            strokePath.stroke()
        }
    }
}

// MARK: - Gradient Card Background

final class GradientCardView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = Theme.cardBorder.cgColor
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Subtle diagonal gradient: dark purple-slate
        let topColor = NSColor(srgbRed: 0.09, green: 0.095, blue: 0.155, alpha: 1).cgColor
        let bottomColor = NSColor(srgbRed: 0.065, green: 0.07, blue: 0.115, alpha: 1).cgColor

        let colors = [topColor, bottomColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: bounds.midX * 0.85, y: bounds.maxY),
                               end: CGPoint(x: bounds.midX * 1.15, y: bounds.minY),
                               options: [])
    }
}
