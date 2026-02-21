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
        let radius = (size - 20) / 2
        let lineWidth: CGFloat = 10

        // Arc with ~70° gap centered at bottom
        // In CG (y-up): 0°=right, 90°=up, 180°=left, 270°=down
        // Start at 235° (bottom-left), end at 305° (bottom-right)
        // Clockwise = decreasing angles: 235->180->90->0->305
        let startAngle = 235.0 * CGFloat.pi / 180   // bottom-left
        let endAngle = 305.0 * CGFloat.pi / 180     // bottom-right
        let totalSweep = 290.0 * CGFloat.pi / 180   // 360 - 70 gap

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

            // Gradient: blue at start (left) -> red at end (right)
            ctx.addPath(strokedFill)
            ctx.clip()
            let colors = [
                NSColor(srgbRed: 0.20, green: 0.50, blue: 0.95, alpha: 1).cgColor,
                NSColor(srgbRed: 0.90, green: 0.35, blue: 0.20, alpha: 1).cgColor,
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
                ctx.drawLinearGradient(gradient,
                                       start: CGPoint(x: centerX - radius - lineWidth, y: centerY),
                                       end: CGPoint(x: centerX + radius + lineWidth, y: centerY),
                                       options: [])
            }
            ctx.restoreGState()
        }

        // "SESSION USAGE" label
        let labelText = "SESSION USAGE" as NSString
        let labelFontSize: CGFloat = size * 0.065
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.font(ofSize: labelFontSize, weight: .medium),
            .foregroundColor: Theme.textSecondary,
        ]
        let labelSize = labelText.size(withAttributes: labelAttrs)

        // Percentage text
        let pctText = String(format: "%.0f%%", utilization) as NSString
        let pctFontSize: CGFloat = size * 0.22
        let pctAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.monospacedDigitFont(ofSize: pctFontSize, weight: .medium),
            .foregroundColor: Theme.textPrimary,
        ]
        let pctSize = pctText.size(withAttributes: pctAttrs)

        // Stack vertically with spacing
        let gap: CGFloat = 4
        let totalTextHeight = labelSize.height + gap + pctSize.height
        let textBlockTop = centerY + totalTextHeight / 2

        labelText.draw(at: NSPoint(x: centerX - labelSize.width / 2, y: textBlockTop - labelSize.height), withAttributes: labelAttrs)
        pctText.draw(at: NSPoint(x: centerX - pctSize.width / 2, y: textBlockTop - labelSize.height - gap - pctSize.height), withAttributes: pctAttrs)

        // Reset time below percentage
        let resetStr: String
        if let resetsAt {
            resetStr = "Resets in \(Formatters.formatTimeRemaining(until: resetsAt))"
        } else {
            resetStr = ""
        }
        guard !resetStr.isEmpty else { return }
        let resetFontSize: CGFloat = size * 0.055
        let resetAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.font(ofSize: resetFontSize),
            .foregroundColor: Theme.textTertiary,
        ]
        let resetSize = (resetStr as NSString).size(withAttributes: resetAttrs)
        let resetY = textBlockTop - labelSize.height - gap - pctSize.height - gap - resetSize.height
        (resetStr as NSString).draw(at: NSPoint(x: centerX - resetSize.width / 2, y: resetY), withAttributes: resetAttrs)
    }
}
