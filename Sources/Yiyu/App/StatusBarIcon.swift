import AppKit
import YiyuCore

/// The menu bar icon: a moon gate standing on the ground, like the collapsed badge. Inside the
/// gate is a plum blossom, or the weather outside when there is some to show. Laid out top-down
/// on an 18 × 18 template, so the menu bar tints it.
enum StatusBarIcon {
    private static let size: CGFloat = 18
    private static let gateCenter = NSPoint(x: 9, y: 10.02)
    private static let gateRadius: CGFloat = 6.8
    private static let ground: CGFloat = 15.2
    private static let lineWidth: CGFloat = 1.35
    /// The middle of the opening, where the blossom or the weather sits.
    private static let middle = NSPoint(x: 9, y: 9.4)

    static func image(for motif: WeatherScene.Motif) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            NSColor.black.set()
            drawGate()
            switch motif {
            case .blossom: drawBlossom()
            case .sun: drawSun()
            case .moon: drawMoon()
            case .rain: drawRain()
            case .snow: drawSnow()
            case .mist: drawMist()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawGate() {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: ground)).addClip()
        let gate = NSBezierPath(ovalIn: NSRect(
            x: gateCenter.x - gateRadius, y: gateCenter.y - gateRadius, width: gateRadius * 2, height: gateRadius * 2
        ))
        gate.lineWidth = lineWidth
        gate.stroke()
        NSGraphicsContext.restoreGraphicsState()

        stroke(from: NSPoint(x: 1.2, y: ground), to: NSPoint(x: 16.8, y: ground), width: lineWidth)
    }

    private static func drawBlossom() {
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: 9, y: 12.4))
        stem.curve(to: NSPoint(x: 7.6, y: ground), controlPoint1: NSPoint(x: 8.87, y: 13.47), controlPoint2: NSPoint(x: 8.4, y: 14.4))
        stem.lineWidth = 1.1
        stem.lineCapStyle = .round
        stem.stroke()

        let blossom = NSPoint(x: 9, y: 9.3)
        for index in 0..<5 {
            let angle = (-90 + CGFloat(index) * 72) * .pi / 180
            circle(at: NSPoint(x: blossom.x + cos(angle) * 2.22, y: blossom.y + sin(angle) * 2.22), radius: 1.63).fill()
        }
        punch(circle(at: blossom, radius: 0.95))
    }

    private static func drawSun() {
        circle(at: middle, radius: 2.05).fill()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            stroke(
                from: NSPoint(x: middle.x + cos(angle) * 3.25, y: middle.y + sin(angle) * 3.25),
                to: NSPoint(x: middle.x + cos(angle) * 4.45, y: middle.y + sin(angle) * 4.45),
                width: 1.1
            )
        }
    }

    /// A crescent opening to the upper right, and one small star.
    private static func drawMoon() {
        circle(at: NSPoint(x: 8.6, y: 9.8), radius: 3.6).fill()
        punch(circle(at: NSPoint(x: 10.5, y: 8.4), radius: 3.05))
        circle(at: NSPoint(x: 12.3, y: 12.3), radius: 0.75).fill()
    }

    /// Two staggered rows of slanting drops.
    private static func drawRain() {
        let drops = [(6.3, 5.6), (9.3, 4.9), (12.3, 5.6), (4.9, 9.9), (7.9, 9.2), (10.9, 9.9)]
        for (x, y) in drops {
            stroke(from: NSPoint(x: x + 0.9, y: y), to: NSPoint(x: x, y: y + 2.7), width: 1.15)
        }
    }

    private static func drawSnow() {
        let flakes = [(6.4, 6.6), (10.6, 5.6), (13, 9.4), (8.4, 9.6), (5, 11.8), (10.8, 12.6)]
        for (x, y) in flakes {
            circle(at: NSPoint(x: x, y: y), radius: 0.95).fill()
        }
    }

    private static func drawMist() {
        stroke(from: NSPoint(x: 5.8, y: 7), to: NSPoint(x: 12.2, y: 7), width: 1.15)
        stroke(from: NSPoint(x: 4.2, y: 9.9), to: NSPoint(x: 13.8, y: 9.9), width: 1.15)
        stroke(from: NSPoint(x: 5.2, y: 12.8), to: NSPoint(x: 11.4, y: 12.8), width: 1.15)
    }

    private static func stroke(from start: NSPoint, to end: NSPoint, width: CGFloat) {
        let line = NSBezierPath()
        line.move(to: start)
        line.line(to: end)
        line.lineWidth = width
        line.lineCapStyle = .round
        line.stroke()
    }

    private static func circle(at center: NSPoint, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// Cuts `path` out of what is drawn so far.
    private static func punch(_ path: NSBezierPath) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
