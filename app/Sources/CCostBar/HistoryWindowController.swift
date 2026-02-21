import AppKit
import CCostLib

private final class HistoryWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "w" else {
            return super.performKeyEquivalent(with: event)
        }
        close()
        return true
    }
}

@MainActor
final class HistoryWindowController {
    private var window: NSWindow?
    private let historyView = HistoryView()
    private let costService = CostService()

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            refreshData()
            return
        }

        let w = HistoryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 740),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Cost History"
        w.setFrameAutosaveName("CCostBarHistoryWindow")
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.backgroundColor = Theme.background
        w.appearance = NSAppearance(named: .darkAqua)
        w.minSize = NSSize(width: 640, height: 320)
        w.center()

        historyView.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = historyView

        self.window = w

        refreshData()

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshData() {
        Task.detached { [costService] in
            let history = costService.fetchHistory(days: 30)
            await MainActor.run { [weak self] in
                self?.historyView.updateData(history)
            }
        }
    }
}
