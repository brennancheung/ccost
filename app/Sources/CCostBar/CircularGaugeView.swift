import AppKit

final class CircularGaugeView: NSView {
    private let utilization: Double
    private let resetsAt: Date?

    init(utilization: Double, resetsAt: Date?, frame: NSRect) {
        self.utilization = utilization
        self.resetsAt = resetsAt
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let size = min(bounds.width, bounds.height)
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radius = (size - 24) / 2
        let lineWidth: CGFloat = 10

        // Arc angles: 270 degrees, starting from bottom-left to bottom-right clockwise
        let startAngle = CGFloat.pi * 0.75
        let endAngle = -CGFloat.pi * 0.75
        let totalSweep = CGFloat.pi * 1.5

        // Draw track
        ctx.saveGState()
        let trackPath = CGMutablePath()
        trackPath.addArc(center: CGPoint(x: centerX, y: centerY), radius: radius,
                         startAngle: startAngle, endAngle: endAngle, clockwise: true)
        let strokedTrack = trackPath.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)
        ctx.addPath(strokedTrack)
        ctx.setFillColor(Theme.gaugeTrack.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Draw filled arc proportional to utilization
        let fraction = CGFloat(min(max(utilization / 100.0, 0), 1.0))
        if fraction > 0 {
            ctx.saveGState()
            let fillAngle = startAngle - (totalSweep * fraction)
            let fillPath = CGMutablePath()
            fillPath.addArc(center: CGPoint(x: centerX, y: centerY), radius: radius,
                            startAngle: startAngle, endAngle: fillAngle, clockwise: true)
            let strokedFill = fillPath.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)

            // 3-color gradient: red -> orange -> blue
            ctx.addPath(strokedFill)
            ctx.clip()
            let colors = [
                Theme.gaugeArcStart.cgColor,
                Theme.gaugeArcEnd.cgColor,
                NSColor(srgbRed: 0.30, green: 0.50, blue: 0.95, alpha: 1).cgColor,
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.45, 1]) {
                let gradientStart = CGPoint(x: centerX - radius, y: centerY - radius)
                let gradientEnd = CGPoint(x: centerX + radius, y: centerY + radius)
                ctx.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
            }
            ctx.restoreGState()
        }

        // "SESSION USAGE" label above percentage
        let labelText = "SESSION USAGE" as NSString
        let labelFontSize: CGFloat = size * 0.075
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.font(ofSize: labelFontSize, weight: .bold),
            .foregroundColor: Theme.textPrimary,
        ]
        let labelSize = labelText.size(withAttributes: labelAttrs)

        // Center percentage text
        let pctText = String(format: "%.0f%%", utilization) as NSString
        let pctFontSize: CGFloat = size * 0.28
        let pctAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.monospacedDigitFont(ofSize: pctFontSize, weight: .bold),
            .foregroundColor: Theme.textPrimary,
        ]
        let pctSize = pctText.size(withAttributes: pctAttrs)

        // Stack: SESSION USAGE, then percentage, then reset time
        let totalTextHeight = labelSize.height + 2 + pctSize.height
        let textBlockTop = centerY + totalTextHeight / 2

        labelText.draw(at: NSPoint(x: centerX - labelSize.width / 2, y: textBlockTop - labelSize.height), withAttributes: labelAttrs)
        pctText.draw(at: NSPoint(x: centerX - pctSize.width / 2, y: textBlockTop - labelSize.height - 2 - pctSize.height), withAttributes: pctAttrs)

        // Reset time below percentage
        let resetStr: String
        if let resetsAt {
            resetStr = "Resets in \(Formatters.formatTimeRemaining(until: resetsAt))"
        } else {
            resetStr = ""
        }
        guard !resetStr.isEmpty else { return }
        let resetFontSize: CGFloat = size * 0.065
        let resetAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.font(ofSize: resetFontSize),
            .foregroundColor: Theme.textTertiary,
        ]
        let resetSize = (resetStr as NSString).size(withAttributes: resetAttrs)
        let resetY = textBlockTop - labelSize.height - 2 - pctSize.height - 2 - resetSize.height
        (resetStr as NSString).draw(at: NSPoint(x: centerX - resetSize.width / 2, y: resetY), withAttributes: resetAttrs)
    }
}
