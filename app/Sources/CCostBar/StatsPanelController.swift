import AppKit
import CCostLib

private final class StatsPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.keyCode == 53 else { return super.performKeyEquivalent(with: event) }
        orderOut(nil)
        return true
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class StatsPanelController {
    private var panel: StatsPanel?
    private var resignObserver: NSObjectProtocol?
    private let costService = CostService()
    private var historyData: [DailySummary]?

    var costData: CostData?
    var rateLimitData: RateLimitData?
    var costError: String?
    var rateLimitError: String?
    var lastRefresh: Date?

    private let panelWidth: CGFloat = 684
    private let maxPanelHeight: CGFloat = 1060

    func toggle() {
        guard let panel, panel.isVisible else {
            show()
            return
        }
        dismiss()
    }

    func show() {
        let panel = ensurePanel()
        rebuildContent(in: panel)
        centerOnScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }

        fetchHistory()
    }

    func dismiss() {
        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
        panel?.orderOut(nil)
    }

    func update() {
        guard let panel, panel.isVisible else { return }
        rebuildContent(in: panel)
    }

    // MARK: - Private

    private func fetchHistory() {
        Task.detached { [costService] in
            let history = costService.fetchHistory(days: 30)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.historyData = history
                guard let panel = self.panel, panel.isVisible else { return }
                self.rebuildContent(in: panel)
            }
        }
    }

    private func ensurePanel() -> StatsPanel {
        if let existing = panel { return existing }

        let p = StatsPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: maxPanelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.isMovableByWindowBackground = true

        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = Theme.background.cgColor
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true
        bg.layer?.borderWidth = 1
        bg.layer?.borderColor = Theme.cardBorder.cgColor
        p.contentView = bg

        self.panel = p
        return p
    }

    private func rebuildContent(in panel: StatsPanel) {
        guard let bg = panel.contentView else { return }
        bg.subviews.forEach { $0.removeFromSuperview() }

        // Stats section
        let statsView = MenuContentView(
            costData: costData,
            rateLimitData: rateLimitData,
            costError: costError,
            rateLimitError: rateLimitError,
            lastRefresh: lastRefresh,
            width: panelWidth
        )
        let statsHeight = statsView.frame.height

        // Container
        let container = FlippedView()
        statsView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: statsHeight)
        container.addSubview(statsView)

        var totalHeight = statsHeight

        // History section (only if data loaded)
        if let data = historyData, !data.isEmpty {
            let sectionPadding: CGFloat = 12
            let sectionWidth = panelWidth - sectionPadding * 2
            let cardInset: CGFloat = 14

            // Stats summary section (30D TOTAL / AVG/DAY / MAX DAY)
            let sectionGap: CGFloat = 20
            let summaryY = statsHeight + sectionGap
            let summaryBottom = addStatsSummary(data, at: summaryY, in: container)

            // "HISTORICAL DATA" header + content in gradient card
            let cardY = summaryBottom + sectionGap
            let headerLabel = NSTextField(labelWithString: "HISTORICAL DATA")
            headerLabel.font = Theme.font(ofSize: 13, weight: .bold)
            headerLabel.textColor = Theme.textPrimary
            headerLabel.isBordered = false
            headerLabel.isEditable = false
            headerLabel.backgroundColor = .clear
            headerLabel.frame = NSRect(x: sectionPadding + cardInset, y: cardY + cardInset, width: sectionWidth - cardInset * 2, height: 18)
            container.addSubview(headerLabel)

            let historyContent = HistoryContentView()
            historyContent.drawsBackground = false
            historyContent.showKPIStrip = false
            historyContent.availableWidth = sectionWidth - cardInset * 2
            historyContent.updateData(data)
            let historyHeight = historyContent.frame.height

            let historyY = cardY + cardInset + 24
            historyContent.frame = NSRect(x: sectionPadding + cardInset, y: historyY, width: sectionWidth - cardInset * 2, height: historyHeight)
            container.addSubview(historyContent)

            let cardHeight = cardInset + 24 + historyHeight + cardInset
            let cardBg = GradientCardView(frame: NSRect(x: sectionPadding, y: cardY, width: sectionWidth, height: cardHeight))
            container.addSubview(cardBg, positioned: .below, relativeTo: container.subviews.first)

            totalHeight = cardY + cardHeight + 12
        }

        totalHeight = totalHeight + 64
        container.frame = NSRect(x: 0, y: 0, width: panelWidth, height: totalHeight)

        // Scroll view
        let visibleHeight = min(totalHeight, maxPanelHeight)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: visibleHeight))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = container
        bg.addSubview(scrollView)

        // Resize panel, keeping top edge fixed
        let oldFrame = panel.frame
        let topEdge = oldFrame.origin.y + oldFrame.height
        let newFrame = NSRect(x: oldFrame.origin.x, y: topEdge - visibleHeight, width: panelWidth, height: visibleHeight)
        panel.setFrame(newFrame, display: true)
        bg.frame = NSRect(origin: .zero, size: NSSize(width: panelWidth, height: visibleHeight))
        scrollView.frame = bg.bounds
    }

    private func addStatsSummary(_ data: [DailySummary], at y: CGFloat, in container: NSView) -> CGFloat {
        let sidePadding: CGFloat = 12
        let contentWidth = panelWidth - sidePadding * 2
        let sectionHeight: CGFloat = 88

        // Calculate stats
        var total = 0.0
        var maxDay: DailySummary?
        for day in data {
            total += day.cost
            if maxDay == nil || day.cost > (maxDay?.cost ?? 0) {
                maxDay = day
            }
        }
        let avg = data.isEmpty ? 0 : total / Double(data.count)

        let maxDayLabel: String
        let maxDayCost: Double
        if let maxDay {
            let isoFmt = DateFormatter()
            isoFmt.locale = Locale(identifier: "en_US_POSIX")
            isoFmt.dateFormat = "yyyy-MM-dd"
            let shortFmt = DateFormatter()
            shortFmt.locale = Locale(identifier: "en_US_POSIX")
            shortFmt.dateFormat = "MMM d"
            if let date = isoFmt.date(from: maxDay.date) {
                maxDayLabel = shortFmt.string(from: date)
            } else {
                maxDayLabel = ""
            }
            maxDayCost = maxDay.cost
        } else {
            maxDayLabel = ""
            maxDayCost = 0
        }

        // Card background with gradient
        let bg = GradientCardView(frame: NSRect(x: sidePadding, y: y, width: contentWidth, height: sectionHeight))
        container.addSubview(bg)

        // Three columns
        let colWidth = contentWidth / 3
        let innerPad: CGFloat = 16

        let items: [(String, String)] = [
            ("30D TOTAL", Formatters.formatCost(total)),
            ("AVG / DAY", Formatters.formatCost(avg)),
            ("MAX DAY \(maxDayLabel)", Formatters.formatCost(maxDayCost)),
        ]

        for (idx, item) in items.enumerated() {
            let x = sidePadding + CGFloat(idx) * colWidth + innerPad

            let label = NSTextField(labelWithString: item.0)
            label.font = Theme.font(ofSize: 13, weight: .medium)
            label.textColor = Theme.textTertiary
            label.isBordered = false
            label.isEditable = false
            label.backgroundColor = .clear
            label.frame = NSRect(x: x, y: y + 16, width: colWidth - innerPad, height: 16)
            container.addSubview(label)

            let value = NSTextField(labelWithString: item.1)
            value.font = Theme.monospacedDigitFont(ofSize: 28, weight: .medium)
            value.textColor = Theme.textPrimary
            value.isBordered = false
            value.isEditable = false
            value.backgroundColor = .clear
            value.frame = NSRect(x: x, y: y + 36, width: colWidth - innerPad, height: 36)
            container.addSubview(value)
        }

        return y + sectionHeight
    }

    private func centerOnScreen(_ panel: StatsPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2 + screenFrame.height * 0.1
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
