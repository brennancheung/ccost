import AppKit
import CoreText

enum Theme {
    // MARK: - Backgrounds (dark purple-slate)
    static let background = NSColor(srgbRed: 0.055, green: 0.06, blue: 0.10, alpha: 1)          // #0e0f1a
    static let cardBackground = NSColor(srgbRed: 0.075, green: 0.08, blue: 0.14, alpha: 1)      // #131424
    static let cardBorder = NSColor.white.withAlphaComponent(0.07)
    static let cardGlow = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.15)

    // MARK: - Text
    static let textPrimary = NSColor.white
    static let textSecondary = NSColor.white.withAlphaComponent(0.60)
    static let textTertiary = NSColor.white.withAlphaComponent(0.35)
    static let textAccent = NSColor(srgbRed: 0.30, green: 0.78, blue: 0.90, alpha: 1)           // cyan accent

    // MARK: - Progress bars
    static let barGradientStart = NSColor(srgbRed: 0.20, green: 0.45, blue: 0.90, alpha: 1)     // blue
    static let barGradientEnd = NSColor(srgbRed: 0.25, green: 0.70, blue: 0.95, alpha: 1)       // blue-cyan
    static let barGlow = NSColor(srgbRed: 0.25, green: 0.55, blue: 0.95, alpha: 0.5)
    static let barTrack = NSColor.white.withAlphaComponent(0.08)

    // MARK: - History bars
    static let historyBarStart = NSColor(srgbRed: 0.25, green: 0.70, blue: 0.90, alpha: 0.96)     // blue-cyan
    static let historyBarEnd = NSColor(srgbRed: 0.90, green: 0.35, blue: 0.20, alpha: 0.96)     // orange-red

    // MARK: - Gauge
    static let gaugeArcStart = NSColor(srgbRed: 0.85, green: 0.20, blue: 0.15, alpha: 1)        // red
    static let gaugeArcEnd = NSColor(srgbRed: 0.95, green: 0.60, blue: 0.15, alpha: 1)          // orange
    static let gaugeTrack = NSColor.white.withAlphaComponent(0.08)

    // MARK: - KPI chips
    static let kpiBackground = NSColor.white.withAlphaComponent(0.04)
    static let kpiBorder = NSColor.white.withAlphaComponent(0.08)

    // MARK: - Utility
    static let zebraStripe = NSColor.white.withAlphaComponent(0.03)
    static let totalRowBackground = NSColor.white.withAlphaComponent(0.06)
    static let divider = NSColor.white.withAlphaComponent(0.10)
    static let errorRed = NSColor(srgbRed: 0.95, green: 0.30, blue: 0.25, alpha: 1)

    // MARK: - Fonts

    private static let fontsRegistered: Bool = {
        let fontNames = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]
        for name in fontNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Resources") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    static func registerFonts() {
        _ = fontsRegistered
    }

    static func font(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        _ = fontsRegistered
        let name = interName(for: weight)
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    static func monospacedDigitFont(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = font(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
            ]]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    private static func interName(for weight: NSFont.Weight) -> String {
        let weightMap: [(NSFont.Weight, String)] = [
            (.bold, "Inter-Bold"),
            (.semibold, "Inter-SemiBold"),
            (.medium, "Inter-Medium"),
        ]
        return weightMap.first(where: { $0.0 == weight })?.1 ?? "Inter-Regular"
    }
}
