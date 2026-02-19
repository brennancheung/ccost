import Foundation

@MainActor
final class Settings {
    private let defaults = UserDefaults.standard
    private let costIntervalKey = "refreshInterval"
    private let rateLimitIntervalKey = "rateLimitRefreshInterval"
    private let formatKey = "displayFormat"
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

    var displayFormat: DisplayFormat {
        get {
            guard let raw = defaults.string(forKey: formatKey) else { return .costAndPercent }
            return DisplayFormat(rawValue: raw) ?? .costAndPercent
        }
        set { defaults.set(newValue.rawValue, forKey: formatKey) }
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
