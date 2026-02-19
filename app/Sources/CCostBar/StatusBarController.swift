import AppKit

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let settings = Settings()
    private let costService = CostService()
    private let rateLimitService = RateLimitService()
    private var costRefreshManager: RefreshManager?
    private var rateLimitRefreshManager: RefreshManager?

    private var costData: CostData?
    private var rateLimitData: RateLimitData?
    private var costError: String?
    private var rateLimitError: String?
    private var lastCostRefresh: Date?
    private var lastRateLimitRefresh: Date?
    private var historyWindowController: HistoryWindowController?
    private var statsPanelController: StatsPanelController?
    private var globalHotKey: GlobalHotKey?

    override init() {
        super.init()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "com.brennan.ccostbar"
        item.button?.title = "..."
        self.statusItem = item

        costRefreshManager = RefreshManager { [weak self] in
            self?.refreshCost()
        }
        rateLimitRefreshManager = RefreshManager { [weak self] in
            self?.refreshRateLimits()
        }

        buildMenu()
        registerHotKey()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.refreshCost()
            self.refreshRateLimits()
            self.costRefreshManager?.start(seconds: self.settings.costRefreshInterval.rawValue)
            self.rateLimitRefreshManager?.start(seconds: self.settings.rateLimitRefreshInterval.rawValue)
        }
    }

    // MARK: - Refresh

    private func refreshCost() {
        Task { @MainActor in
            await fetchCost()
            lastCostRefresh = Date()
            updateMenuBarTitle()
            buildMenu()
            updateStatsPanel()
        }
    }

    private func refreshRateLimits() {
        Task { @MainActor in
            await fetchRateLimits()
            lastRateLimitRefresh = Date()
            updateMenuBarTitle()
            buildMenu()
            updateStatsPanel()
        }
    }

    private func refreshAll() {
        Task { @MainActor in
            async let c: Void = fetchCost()
            async let r: Void = fetchRateLimits()
            await c
            await r
            lastCostRefresh = Date()
            lastRateLimitRefresh = Date()
            updateMenuBarTitle()
            buildMenu()
        }
    }

    private func registerHotKey() {
        globalHotKey?.unregister()
        globalHotKey = nil
        let combo = settings.hotKeyCombo
        guard combo != .disabled else { return }
        globalHotKey = GlobalHotKey(keyCode: combo.keyCode, modifiers: combo.carbonModifiers) { [weak self] in
            self?.toggleStatsPanel()
        }
    }

    private func toggleStatsPanel() {
        let controller = statsPanelController ?? StatsPanelController()
        statsPanelController = controller
        controller.costData = costData
        controller.rateLimitData = rateLimitData
        controller.costError = costError
        controller.rateLimitError = rateLimitError
        controller.lastRefresh = lastCostRefresh
        controller.toggle()
    }

    private func updateStatsPanel() {
        guard let controller = statsPanelController else { return }
        controller.costData = costData
        controller.rateLimitData = rateLimitData
        controller.costError = costError
        controller.rateLimitError = rateLimitError
        controller.lastRefresh = lastCostRefresh
        controller.update()
    }

    private func fetchCost() async {
        let result = await Task.detached { [costService] in
            costService.fetchTodayCost()
        }.value
        costData = result
        costError = nil
    }

    private func fetchRateLimits() async {
        do {
            rateLimitData = try await rateLimitService.fetchUsage()
            rateLimitError = nil
        } catch {
            rateLimitError = describeError(error)
        }
    }

    private func describeError(_ error: Error) -> String {
        if case ServiceError.processFailure(let msg) = error { return "Process: \(msg)" }
        if case ServiceError.parseFailure(let msg) = error { return "Parse: \(msg)" }
        if case ServiceError.keychainFailure(let msg) = error { return "Keychain: \(msg)" }
        if case ServiceError.networkFailure(let msg) = error { return "Network: \(msg)" }
        return error.localizedDescription
    }

    private func updateMenuBarTitle() {
        statusItem?.button?.title = Formatters.formatMenuBar(
            cost: costData?.cost,
            rateLimits: rateLimitData,
            format: settings.displayFormat
        )
    }

    // MARK: - Menu Construction

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Custom data view
        let contentView = MenuContentView(
            costData: costData,
            rateLimitData: rateLimitData,
            costError: costError,
            rateLimitError: rateLimitError,
            lastRefresh: lastCostRefresh
        )
        let contentItem = NSMenuItem()
        contentItem.view = contentView
        menu.addItem(contentItem)

        menu.addItem(NSMenuItem.separator())
        addCostHistoryItem(to: menu)
        menu.addItem(NSMenuItem.separator())
        addRefreshNowItem(to: menu)
        addCostRefreshSubmenu(to: menu)
        addRateLimitRefreshSubmenu(to: menu)
        menu.addItem(NSMenuItem.separator())
        addDisplayFormatSubmenu(to: menu)
        addHotKeySubmenu(to: menu)
        menu.addItem(NSMenuItem.separator())
        addLaunchAtLoginItem(to: menu)
        menu.addItem(NSMenuItem.separator())
        addQuitItem(to: menu)

        statusItem?.menu = menu
    }

    private func addCostHistoryItem(to menu: NSMenu) {
        let item = NSMenuItem(title: "Cost History...", action: #selector(costHistoryClicked), keyEquivalent: "h")
        item.keyEquivalentModifierMask = .command
        item.target = self
        menu.addItem(item)
    }

    private func addRefreshNowItem(to menu: NSMenu) {
        let item = NSMenuItem(title: "Refresh Now", action: #selector(refreshNowClicked), keyEquivalent: "r")
        item.target = self
        menu.addItem(item)
    }

    private func addCostRefreshSubmenu(to menu: NSMenu) {
        let submenu = NSMenu()
        let current = settings.costRefreshInterval

        for interval in CostRefreshInterval.allCases {
            let label = costRefreshLabels[interval] ?? "\(interval.rawValue)s"
            let item = NSMenuItem(title: label, action: #selector(costIntervalSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = interval.rawValue
            item.state = (interval == current) ? .on : .off
            submenu.addItem(item)
        }

        let container = NSMenuItem(title: "Cost Refresh", action: nil, keyEquivalent: "")
        container.submenu = submenu
        menu.addItem(container)
    }

    private func addRateLimitRefreshSubmenu(to menu: NSMenu) {
        let submenu = NSMenu()
        let current = settings.rateLimitRefreshInterval

        for interval in RateLimitRefreshInterval.allCases {
            let label = rateLimitRefreshLabels[interval] ?? "\(interval.rawValue)s"
            let item = NSMenuItem(title: label, action: #selector(rateLimitIntervalSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = interval.rawValue
            item.state = (interval == current) ? .on : .off
            submenu.addItem(item)
        }

        let container = NSMenuItem(title: "Usage Limit Refresh", action: nil, keyEquivalent: "")
        container.submenu = submenu
        menu.addItem(container)
    }

    private func addDisplayFormatSubmenu(to menu: NSMenu) {
        let submenu = NSMenu()
        let currentFormat = settings.displayFormat

        for format in DisplayFormat.allCases {
            let label = Formatters.displayFormatLabel(format)
            let item = NSMenuItem(title: label, action: #selector(formatSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue as NSString
            item.state = (format == currentFormat) ? .on : .off
            submenu.addItem(item)
        }

        let container = NSMenuItem(title: "Display Format", action: nil, keyEquivalent: "")
        container.submenu = submenu
        menu.addItem(container)
    }

    private func addHotKeySubmenu(to menu: NSMenu) {
        let submenu = NSMenu()
        let current = settings.hotKeyCombo

        for combo in HotKeyCombo.allCases {
            let label = Formatters.hotKeyComboLabel(combo)
            let item = NSMenuItem(title: label, action: #selector(hotKeySelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = combo.rawValue as NSString
            item.state = (combo == current) ? .on : .off
            submenu.addItem(item)
        }

        let container = NSMenuItem(title: "Global Hotkey", action: nil, keyEquivalent: "")
        container.submenu = submenu
        menu.addItem(container)
    }

    private func addLaunchAtLoginItem(to menu: NSMenu) {
        let item = NSMenuItem(title: "Launch at Login", action: #selector(launchAtLoginToggled), keyEquivalent: "")
        item.target = self
        item.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(item)
    }

    private func addQuitItem(to menu: NSMenu) {
        let item = NSMenuItem(title: "Quit CCostBar", action: #selector(quitClicked), keyEquivalent: "q")
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func costHistoryClicked() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController()
        }
        historyWindowController?.showWindow()
    }

    @objc private func refreshNowClicked() {
        refreshAll()
    }

    @objc private func costIntervalSelected(_ sender: NSMenuItem) {
        guard let interval = CostRefreshInterval(rawValue: sender.tag) else { return }
        settings.costRefreshInterval = interval
        costRefreshManager?.stop()
        costRefreshManager?.start(seconds: interval.rawValue)
        rebuildMenuDeferred()
    }

    @objc private func rateLimitIntervalSelected(_ sender: NSMenuItem) {
        guard let interval = RateLimitRefreshInterval(rawValue: sender.tag) else { return }
        settings.rateLimitRefreshInterval = interval
        rateLimitRefreshManager?.stop()
        rateLimitRefreshManager?.start(seconds: interval.rawValue)
        rebuildMenuDeferred()
    }

    @objc private func formatSelected(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? NSString else { return }
        guard let format = DisplayFormat(rawValue: rawValue as String) else { return }
        settings.displayFormat = format
        updateMenuBarTitle()
        rebuildMenuDeferred()
    }

    @objc private func hotKeySelected(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? NSString else { return }
        guard let combo = HotKeyCombo(rawValue: rawValue as String) else { return }
        settings.hotKeyCombo = combo
        registerHotKey()
        rebuildMenuDeferred()
    }

    @objc private func launchAtLoginToggled() {
        LaunchAtLogin.toggle()
        settings.launchAtLogin = LaunchAtLogin.isEnabled
        rebuildMenuDeferred()
    }

    private func rebuildMenuDeferred() {
        DispatchQueue.main.async { [weak self] in
            self?.buildMenu()
        }
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }
}
