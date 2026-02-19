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

    private let panelWidth: CGFloat = 900
    private let maxPanelHeight: CGFloat = 700

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

        let vibrancy = NSVisualEffectView()
        vibrancy.material = .popover
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = 12
        vibrancy.layer?.masksToBounds = true
        p.contentView = vibrancy

        self.panel = p
        return p
    }

    private func rebuildContent(in panel: StatsPanel) {
        guard let vibrancy = panel.contentView as? NSVisualEffectView else { return }
        vibrancy.subviews.forEach { $0.removeFromSuperview() }

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
            let historyPadding: CGFloat = 12
            let historyWidth = panelWidth - historyPadding * 2
            let dividerY = statsHeight + 4

            let divider = NSBox(frame: NSRect(x: 16, y: dividerY, width: panelWidth - 32, height: 1))
            divider.boxType = .separator
            container.addSubview(divider)

            let historyContent = HistoryContentView()
            historyContent.drawsBackground = false
            historyContent.availableWidth = historyWidth
            historyContent.updateData(data)
            let historyHeight = historyContent.frame.height

            let historyY = dividerY + 9
            historyContent.frame = NSRect(x: historyPadding, y: historyY, width: historyWidth, height: historyHeight)
            container.addSubview(historyContent)

            totalHeight = historyY + historyHeight + 12
        }

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
        vibrancy.addSubview(scrollView)

        // Resize panel, keeping top edge fixed
        let oldFrame = panel.frame
        let topEdge = oldFrame.origin.y + oldFrame.height
        let newFrame = NSRect(x: oldFrame.origin.x, y: topEdge - visibleHeight, width: panelWidth, height: visibleHeight)
        panel.setFrame(newFrame, display: true)
        vibrancy.frame = NSRect(origin: .zero, size: NSSize(width: panelWidth, height: visibleHeight))
        scrollView.frame = vibrancy.bounds
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
