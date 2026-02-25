import Foundation

@MainActor
final class Settings {
    private let defaults = UserDefaults.standard
    private let costIntervalKey = "refreshInterval"
    private let rateLimitIntervalKey = "rateLimitRefreshInterval"
    private let showCostKey = "showCost"
    private let showWeeklyPercentKey = "showWeeklyPercent"
    private let showWeeklyResetTimeKey = "showWeeklyResetTime"
    private let showSessionPercentKey = "showSessionPercent"
    private let showSessionResetTimeKey = "showSessionResetTime"
    private let launchAtLoginKey = "launchAtLogin"
    private let hotKeyComboKey = "hotKeyCombo"

    var costRefreshInterval: CostRefreshInterval {
        get {
            let raw = defaults.integer(forKey: costIntervalKey)
            guard raw > 0 else { return .oneMinute }
            return CostRefreshInterval(rawValue: raw) ?? .oneMinute
        }
        set { defaults.set(newValue.rawValue, forKey: costIntervalKey) }
    }

    var rateLimitRefreshInterval: RateLimitRefreshInterval {
        get {
            let raw = defaults.integer(forKey: rateLimitIntervalKey)
            guard raw > 0 else { return .fifteenMinutes }
            return RateLimitRefreshInterval(rawValue: raw) ?? .fifteenMinutes
        }
        set { defaults.set(newValue.rawValue, forKey: rateLimitIntervalKey) }
    }

    var showCost: Bool {
        get { defaults.object(forKey: showCostKey) != nil ? defaults.bool(forKey: showCostKey) : false }
        set { defaults.set(newValue, forKey: showCostKey) }
    }

    var showWeeklyPercent: Bool {
        get { defaults.object(forKey: showWeeklyPercentKey) != nil ? defaults.bool(forKey: showWeeklyPercentKey) : false }
        set { defaults.set(newValue, forKey: showWeeklyPercentKey) }
    }

    var showWeeklyResetTime: Bool {
        get { defaults.object(forKey: showWeeklyResetTimeKey) != nil ? defaults.bool(forKey: showWeeklyResetTimeKey) : false }
        set { defaults.set(newValue, forKey: showWeeklyResetTimeKey) }
    }

    var showSessionPercent: Bool {
        get { defaults.object(forKey: showSessionPercentKey) != nil ? defaults.bool(forKey: showSessionPercentKey) : true }
        set { defaults.set(newValue, forKey: showSessionPercentKey) }
    }

    var showSessionResetTime: Bool {
        get { defaults.object(forKey: showSessionResetTimeKey) != nil ? defaults.bool(forKey: showSessionResetTimeKey) : true }
        set { defaults.set(newValue, forKey: showSessionResetTimeKey) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: launchAtLoginKey) }
        set { defaults.set(newValue, forKey: launchAtLoginKey) }
    }

    var hotKeyCombo: HotKeyCombo {
        get {
            guard let raw = defaults.string(forKey: hotKeyComboKey) else { return .ctrlShiftC }
            return HotKeyCombo(rawValue: raw) ?? .ctrlShiftC
        }
        set { defaults.set(newValue.rawValue, forKey: hotKeyComboKey) }
    }
}
