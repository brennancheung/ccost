import AppKit
import CCostLib

@MainActor
final class HistoryView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Cost History")
    private let subtitleLabel = NSTextField(labelWithString: "Last 30 days of Claude usage")
    private let cardView = NSView()
    private let scrollView = NSScrollView()
    private let contentView = HistoryContentView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = Theme.background.cgColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Theme.font(ofSize: 22, weight: .semibold)
        titleLabel.textColor = Theme.textPrimary
        addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = Theme.font(ofSize: 12)
        subtitleLabel.textColor = Theme.textSecondary
        addSubview(subtitleLabel)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 12
        cardView.layer?.backgroundColor = Theme.cardBackground.cgColor
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = Theme.cardBorder.cgColor
        cardView.layer?.shadowColor = Theme.cardGlow.cgColor
        cardView.layer?.shadowOpacity = 1
        cardView.layer?.shadowRadius = 14
        cardView.layer?.shadowOffset = NSSize(width: 0, height: -2)
        addSubview(cardView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        cardView.addSubview(scrollView)

        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            cardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
        ])
    }

    override func layout() {
        super.layout()
        syncContentWidth()
    }

    func updateData(_ newData: [DailySummary]) {
        syncContentWidth()
        contentView.updateData(newData)
    }

    private func syncContentWidth() {
        let width = max(scrollView.contentView.bounds.width, 0)
        guard abs(contentView.availableWidth - width) > 0.5 else { return }
        contentView.availableWidth = width
        contentView.recalculate()
    }
}

@MainActor
final class HistoryContentView: NSView {
    override var isFlipped: Bool { true }

    var availableWidth: CGFloat = 720
    var drawsBackground = true
    var showKPIStrip: Bool = true
    private var data: [DailySummary] = []

    // Layout
    private let outerPadding: CGFloat = 10
    private let kpiBandHeight: CGFloat = 48
    private let headerHeight: CGFloat = 18
    private let rowHeight: CGFloat = 18
    private let rowSpacing: CGFloat = 1
    private let totalRowHeight: CGFloat = 22
    private let axisBandHeight: CGFloat = 16
    private let footerPadding: CGFloat = 8
    private let dateWidth: CGFloat = 56
    private let gapSmall: CGFloat = 6
    private let gapLarge: CGFloat = 8

    // Data column widths
    private let colCost: CGFloat = 74
    private let colSess: CGFloat = 50
    private let colIn: CGFloat = 62
    private let colOut: CGFloat = 62
    private let colCacheW: CGFloat = 68
    private let colCacheR: CGFloat = 68

    // Axis state
    private var maxCost: Double = 10
    private var ticks: [Double] = [0, 5, 10]

    // Colors
    private let canvasColor = Theme.cardBackground
    private let zebraColor = Theme.zebraStripe
    private let trackColor = Theme.barTrack
    private let accentStart = Theme.historyBarStart
    private let accentEnd = Theme.historyBarEnd

    // Formatters
    private let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private let tickNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    // Fonts
    private let dateFont = Theme.font(ofSize: 10.5, weight: .semibold)
    private let headerFont = Theme.font(ofSize: 10, weight: .semibold)
    private let valueFont = Theme.monospacedDigitFont(ofSize: 10.5, weight: .medium)
    private let tickFont = Theme.monospacedDigitFont(ofSize: 9)
    private let totalLabelFont = Theme.font(ofSize: 10.5, weight: .semibold)
    private let totalValueFont = Theme.monospacedDigitFont(ofSize: 10.5, weight: .semibold)
    private let kpiTitleFont = Theme.font(ofSize: 9, weight: .semibold)
    private let kpiValueFont = Theme.monospacedDigitFont(ofSize: 13, weight: .bold)

    // Computed layout
    private var dataColumnsWidth: CGFloat { colCost + colSess + colIn + colOut + colCacheW + colCacheR }
    private var barLeft: CGFloat { outerPadding + dateWidth + gapSmall }
    private var barWidth: CGFloat {
        max(220, availableWidth - (outerPadding * 2) - dateWidth - gapSmall - (gapLarge * 2) - dataColumnsWidth)
    }
    private var dividerX: CGFloat { barLeft + barWidth + gapLarge }
    private var tableLeft: CGFloat { dividerX + gapLarge }
    private var rowAreaHeight: CGFloat {
        guard !data.isEmpty else { return 0 }
        return (CGFloat(data.count) * rowHeight) + (CGFloat(max(data.count - 1, 0)) * rowSpacing)
    }

    func updateData(_ newData: [DailySummary]) {
        data = fillMissingDates(newData)
        recalculate()
    }

    func recalculate() {
        let params = calculateAxisParams(data.map(\.cost).max() ?? 1)
        maxCost = params.maxValue
        ticks = params.ticks

        let kpiHeight: CGFloat = showKPIStrip ? (kpiBandHeight + 8) : 0
        let height = outerPadding + kpiHeight + headerHeight + 4 + rowAreaHeight + 4 + totalRowHeight + 6 + axisBandHeight + footerPadding
        frame = NSRect(x: 0, y: 0, width: max(availableWidth, 560), height: max(height, 230))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawBackground()

        guard !data.isEmpty else {
            drawEmptyState()
            return
        }

        var currentY = outerPadding
        if showKPIStrip {
            drawKPIStrip(y: currentY)
            currentY += kpiBandHeight + 8
        }

        let headerY = currentY
        drawHeader(y: headerY)

        let rowsStartY = headerY + headerHeight + 4
        for (index, day) in data.enumerated() {
            let rowY = rowsStartY + CGFloat(index) * (rowHeight + rowSpacing)
            drawRow(day, at: rowY, index: index)
        }

        let separatorY = rowsStartY + rowAreaHeight + 4
        drawHLine(y: separatorY)

        let totalY = separatorY + 3
        drawTotalRow(y: totalY)

        drawVLine(x: dividerX, from: headerY + 2, to: totalY + totalRowHeight)
        let bottomAxisY = totalY + totalRowHeight + 6
        drawAxisLabels(y: bottomAxisY + 1, color: Theme.textTertiary)
    }

    // MARK: - Sections

    private func drawBackground() {
        guard drawsBackground else { return }
        canvasColor.setFill()
        NSBezierPath.fill(bounds)
    }

    private func drawKPIStrip(y: CGFloat) {
        let summary = summarize()
        let maxDayText: String
        if let maxDay = summary.maxDay {
            maxDayText = "\(formatDateShort(maxDay.date))  \(Formatters.formatCost(maxDay.cost))"
        } else {
            maxDayText = "-"
        }

        var x = outerPadding
        let chips: [(String, String)] = [
            ("30D TOTAL", Formatters.formatCost(summary.total)),
            ("AVG / DAY", Formatters.formatCost(summary.averagePerDay)),
            ("MAX DAY", maxDayText),
        ]

        for (idx, chip) in chips.enumerated() {
            let reservedRight = CGFloat(chips.count - idx - 1) * 132
            let maxWidth = (frame.width - outerPadding) - x - reservedRight
            let width = drawKPIChip(title: chip.0, value: chip.1, x: x, y: y, maxWidth: max(maxWidth, 120))
            x += width + 8
        }
    }

    private func drawKPIChip(title: String, value: String, x: CGFloat, y: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: kpiTitleFont,
            .foregroundColor: Theme.textTertiary,
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: Theme.textPrimary,
        ]

        let titleWidth = (title as NSString).size(withAttributes: titleAttrs).width
        let valueWidth = (value as NSString).size(withAttributes: valueAttrs).width
        let width = min(max(126, max(titleWidth, valueWidth) + 20), maxWidth)

        let rect = NSRect(x: x, y: y, width: width, height: kpiBandHeight)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        Theme.kpiBackground.setFill()
        path.fill()
        Theme.kpiBorder.setStroke()
        path.lineWidth = 1
        path.stroke()

        (title as NSString).draw(at: NSPoint(x: x + 10, y: y + 6), withAttributes: titleAttrs)
        (value as NSString).draw(at: NSPoint(x: x + 10, y: y + 22), withAttributes: valueAttrs)
        return width
    }

    private func drawHeader(y: CGFloat) {
        drawAxisLabels(y: y, color: Theme.textTertiary)
        drawColumnHeaders(y: y)
        drawHLine(y: y + headerHeight - 2)
    }

    private func drawRow(_ day: DailySummary, at y: CGFloat, index: Int) {
        if index % 2 == 1 {
            zebraColor.setFill()
            NSBezierPath.fill(NSRect(x: outerPadding - 2, y: y, width: frame.width - ((outerPadding - 2) * 2), height: rowHeight))
        }

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: day.cost > 0 ? Theme.textPrimary : Theme.textSecondary,
        ]
        (formatDateShort(day.date) as NSString).draw(at: NSPoint(x: outerPadding, y: y + 3), withAttributes: dateAttrs)

        Theme.divider.setStroke()
        for tick in ticks {
            let x = barLeft + (barWidth * CGFloat(tick / maxCost))
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: y + 2))
            path.line(to: NSPoint(x: x, y: y + rowHeight - 2))
            path.lineWidth = 0.5
            path.setLineDash([2, 3], count: 2, phase: 0)
            path.stroke()
        }

        let trackRect = NSRect(x: barLeft, y: y + 3, width: barWidth, height: rowHeight - 6)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4)
        trackColor.setFill()
        trackPath.fill()

        if maxCost > 0 && day.cost > 0 {
            let bw = barWidth * CGFloat(day.cost / maxCost)
            let barRect = NSRect(x: barLeft, y: y + 3, width: max(1, bw), height: rowHeight - 6)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4)
            if let gradient = NSGradient(colors: [accentStart, accentEnd]) {
                gradient.draw(in: barPath, angle: 0)
            } else {
                accentStart.setFill()
                barPath.fill()
            }
        }

        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: day.cost > 0 ? Theme.textPrimary : Theme.textSecondary,
        ]

        var x = tableLeft
        drawRightAligned(Formatters.formatCost(day.cost), x: x, y: y + 3, width: colCost, attrs: valAttrs)
        x += colCost
        drawRightAligned("\(day.sessions)", x: x, y: y + 3, width: colSess, attrs: valAttrs)
        x += colSess
        drawRightAligned(Formatters.formatTokens(day.inputTokens), x: x, y: y + 3, width: colIn, attrs: valAttrs)
        x += colIn
        drawRightAligned(Formatters.formatTokens(day.outputTokens), x: x, y: y + 3, width: colOut, attrs: valAttrs)
        x += colOut
        drawRightAligned(Formatters.formatTokens(day.cacheCreationInputTokens), x: x, y: y + 3, width: colCacheW, attrs: valAttrs)
        x += colCacheW
        drawRightAligned(Formatters.formatTokens(day.cacheReadInputTokens), x: x, y: y + 3, width: colCacheR, attrs: valAttrs)
    }

    private func drawTotalRow(y: CGFloat) {
        let totalRect = NSRect(x: outerPadding - 2, y: y, width: frame.width - ((outerPadding - 2) * 2), height: totalRowHeight)
        Theme.totalRowBackground.setFill()
        NSBezierPath.fill(totalRect)
        drawHLine(y: y)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: totalLabelFont,
            .foregroundColor: Theme.textPrimary,
        ]
        ("TOTAL (30D)" as NSString).draw(at: NSPoint(x: outerPadding, y: y + 5), withAttributes: labelAttrs)

        let summary = summarize()
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: totalValueFont,
            .foregroundColor: Theme.textPrimary,
        ]

        var x = tableLeft
        drawRightAligned(Formatters.formatCost(summary.total), x: x, y: y + 5, width: colCost, attrs: valAttrs)
        x += colCost
        drawRightAligned("\(summary.totalSessions)", x: x, y: y + 5, width: colSess, attrs: valAttrs)
        x += colSess
        drawRightAligned(Formatters.formatTokens(summary.totalInput), x: x, y: y + 5, width: colIn, attrs: valAttrs)
        x += colIn
        drawRightAligned(Formatters.formatTokens(summary.totalOutput), x: x, y: y + 5, width: colOut, attrs: valAttrs)
        x += colOut
        drawRightAligned(Formatters.formatTokens(summary.totalCacheW), x: x, y: y + 5, width: colCacheW, attrs: valAttrs)
        x += colCacheW
        drawRightAligned(Formatters.formatTokens(summary.totalCacheR), x: x, y: y + 5, width: colCacheR, attrs: valAttrs)
    }

    // MARK: - Axis

    private func drawAxisLabels(y: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: tickFont,
            .foregroundColor: color,
        ]
        for tick in ticks {
            let x = barLeft + (barWidth * CGFloat(tick / maxCost))
            let label = formatTickLabel(tick) as NSString
            let size = label.size(withAttributes: attrs)
            let minX = barLeft - 2
            let maxX = dividerX - size.width - 4
            let drawX = min(max(x - (size.width / 2), minX), maxX)
            label.draw(at: NSPoint(x: drawX, y: y), withAttributes: attrs)
        }
    }

    private func drawColumnHeaders(y: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: Theme.textSecondary,
        ]
        let headers: [(String, CGFloat)] = [
            ("Cost", colCost),
            ("Sess", colSess),
            ("Input", colIn),
            ("Output", colOut),
            ("Cache W", colCacheW),
            ("Cache R", colCacheR),
        ]
        var x = tableLeft
        for (label, width) in headers {
            drawRightAligned(label, x: x, y: y, width: width, attrs: attrs)
            x += width
        }
    }

    // MARK: - Drawing helpers

    private func drawRightAligned(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, attrs: [NSAttributedString.Key: Any]) {
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: x + width - size.width - 6, y: y), withAttributes: attrs)
    }

    private func drawHLine(y: CGFloat) {
        Theme.divider.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: outerPadding, y: y))
        path.line(to: NSPoint(x: frame.width - outerPadding, y: y))
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawVLine(x: CGFloat, from y1: CGFloat, to y2: CGFloat) {
        Theme.divider.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: y1))
        path.line(to: NSPoint(x: x, y: y2))
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawEmptyState() {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.font(ofSize: 15, weight: .semibold),
            .foregroundColor: Theme.textSecondary,
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.font(ofSize: 12),
            .foregroundColor: Theme.textTertiary,
        ]

        let title = "No cost history yet" as NSString
        let subtitle = "Usage will appear here after your next refresh." as NSString
        let titleSize = title.size(withAttributes: titleAttrs)
        let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
        let centerX = bounds.midX
        let centerY = bounds.midY

        title.draw(at: NSPoint(x: centerX - (titleSize.width / 2), y: centerY - 14), withAttributes: titleAttrs)
        subtitle.draw(at: NSPoint(x: centerX - (subtitleSize.width / 2), y: centerY + 8), withAttributes: subtitleAttrs)
    }

    // MARK: - Summaries

    private func summarize() -> (total: Double, averagePerDay: Double, maxDay: DailySummary?, totalSessions: Int, totalInput: Int, totalOutput: Int, totalCacheW: Int, totalCacheR: Int) {
        var total = 0.0
        var sessions = 0
        var input = 0
        var output = 0
        var cacheW = 0
        var cacheR = 0
        var maxDay: DailySummary?

        for day in data {
            total += day.cost
            sessions += day.sessions
            input += day.inputTokens
            output += day.outputTokens
            cacheW += day.cacheCreationInputTokens
            cacheR += day.cacheReadInputTokens
            if maxDay == nil || day.cost > (maxDay?.cost ?? 0) {
                maxDay = day
            }
        }

        let avg = data.isEmpty ? 0 : total / Double(data.count)
        return (total, avg, maxDay, sessions, input, output, cacheW, cacheR)
    }

    // MARK: - Formatting

    private func formatDateShort(_ dateString: String) -> String {
        guard let date = isoDateFormatter.date(from: dateString) else { return dateString }
        return shortDateFormatter.string(from: date)
    }

    private func formatTickLabel(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 {
            let rounded = tickNumberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            return "$\(rounded)"
        }
        if maxCost < 10 {
            let rounded = tickNumberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
            return "$\(rounded)"
        }
        return "$\(Int(value))"
    }

    // MARK: - Axis math

    private func calculateAxisParams(_ rawMax: Double) -> (maxValue: Double, ticks: [Double]) {
        guard rawMax > 0 else { return (10, [0, 5, 10]) }
        let roughInterval = rawMax / 4
        let magnitude = pow(10, floor(log10(roughInterval)))
        let normalized = roughInterval / magnitude
        let niceValues: [Double] = [1, 2, 2.5, 5, 10]
        let nice = niceValues.first(where: { $0 >= normalized }) ?? 10
        let interval = nice * magnitude

        let maxValue = ceil(rawMax / interval) * interval
        var tickValues: [Double] = []
        var tick = 0.0
        while tick <= maxValue + 0.001 {
            tickValues.append(tick)
            tick += interval
        }
        return (maxValue, tickValues)
    }

    private func fillMissingDates(_ input: [DailySummary]) -> [DailySummary] {
        guard !input.isEmpty else { return input }

        let lookup = Dictionary(uniqueKeysWithValues: input.map { ($0.date, $0) })
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<30).reversed().compactMap { offset -> DailySummary? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = isoDateFormatter.string(from: date)
            return lookup[key] ?? DailySummary(
                date: key,
                cost: 0,
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationInputTokens: 0,
                cacheReadInputTokens: 0,
                sessions: 0
            )
        }.sorted { lhs, rhs in
            guard let lhsDate = isoDateFormatter.date(from: lhs.date),
                  let rhsDate = isoDateFormatter.date(from: rhs.date) else {
                return lhs.date < rhs.date
            }
            return lhsDate > rhsDate
        }
    }
}
