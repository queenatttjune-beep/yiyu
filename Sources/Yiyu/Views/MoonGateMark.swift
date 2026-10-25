import AppKit
import SwiftUI
import YiyuCore

/// Shared garden geometry at badge and menu-bar sizes. Only the flower moves in a breeze.
struct MoonGateMark: View, @MainActor Animatable {
    let scene: GardenScene
    var breeze: Double = 0

    var animatableData: Double {
        get { breeze }
        set { breeze = newValue }
    }

    var body: some View {
        // Read outside Canvas so changing a skin subscribes and redraws the artwork.
        let inks = GardenDrawing.Inks(palette: Theme.skin.palette)
        Canvas { context, size in
            context.withCGContext { cg in
                GardenDrawing.draw(in: cg, size: size, scene: scene, inks: inks, breeze: breeze)
            }
        }
        .accessibilityHidden(true)
    }

    static func menuBarImage(flower: GardenFlower) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            GardenDrawing.draw(in: cg, size: CGSize(width: 18, height: 18),
                               scene: GardenScene(flower: flower), inks: .template, compact: true)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// A tiny vector garden, drawn without bitmap assets or additional network requests.
private struct GardenDrawing {
    struct Inks {
        let paper: CGColor
        let accent: CGColor
        let ink: CGColor
        let snow: CGColor

        init(palette: ThemePalette) {
            paper = Self.color(palette.paper)
            accent = Self.color(palette.accent)
            ink = Self.color(palette.ink)
            snow = Self.color(palette.isDark ? palette.ink : palette.paper)
        }

        private init(paper: CGColor, accent: CGColor, ink: CGColor) {
            self.paper = paper
            self.accent = accent
            self.ink = ink
            self.snow = ink
        }

        static let template = Inks(paper: CGColor(gray: 0, alpha: 0),
                                   accent: CGColor(gray: 0, alpha: 1), ink: CGColor(gray: 0, alpha: 1))

        private static func color(_ color: ThemeColor) -> CGColor {
            CGColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        }
    }

    let cg: CGContext
    let inks: Inks
    let compact: Bool

    static func draw(in cg: CGContext, size: CGSize, scene: GardenScene, inks: Inks,
                     breeze: Double = 0, compact: Bool = false) {
        cg.saveGState()
        defer { cg.restoreGState() }
        let scale = min(size.width, size.height) / 44
        cg.translateBy(x: (size.width - 44 * scale) / 2, y: (size.height - 44 * scale) / 2)
        cg.scaleBy(x: scale, y: scale)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        let drawing = Self(cg: cg, inks: inks, compact: compact)
        let gate = CGRect(x: 6, y: 6, width: 32, height: 32)
        if !compact {
            cg.setFillColor(inks.accent.copy(alpha: scene.isNight ? 0.07 : 0.11)!)
            cg.fillEllipse(in: gate)
            drawing.sky(scene)
        }
        cg.setStrokeColor(compact ? inks.accent : inks.accent.copy(alpha: 0.8)!)
        cg.setLineWidth(compact ? 2.7 : 1.1)
        cg.strokeEllipse(in: gate)

        cg.saveGState()
        if scene.isWindy && !compact {
            cg.translateBy(x: 20, y: 34)
            cg.rotate(by: (-3 + breeze * 5) * .pi / 180)
            cg.translateBy(x: -20, y: -34)
        }
        drawing.plant(scene.flower)
        cg.restoreGState()
        if !compact { drawing.weather(scene) }
    }

    private func plant(_ flower: GardenFlower) {
        let paths = GardenSilhouetteArtwork.paths(for: flower, compact: compact)
        let scale: CGFloat = 44.0 / 128

        // Let the plant pass in front of the gate. Clear only the narrow band around
        // the rim, so the new silhouettes also work when a leaf crosses the circle.
        cg.saveGState()
        let band = CGMutablePath()
        band.addEllipse(in: CGRect(x: 4, y: 4, width: 36, height: 36))
        band.addEllipse(in: CGRect(x: 8, y: 8, width: 28, height: 28))
        cg.addPath(band)
        cg.clip(using: .evenOdd)
        cg.scaleBy(x: scale, y: scale)
        if compact { cg.setBlendMode(.clear) }
        cg.setFillColor(inks.paper)
        cg.setStrokeColor(inks.paper)
        cg.setLineWidth(4)
        for path in paths {
            cg.addPath(path)
            cg.drawPath(using: .fillStroke)
        }
        cg.restoreGState()

        cg.saveGState()
        cg.scaleBy(x: scale, y: scale)
        cg.setFillColor(inks.ink)
        for path in paths {
            cg.addPath(path)
            cg.fillPath()
        }
        cg.restoreGState()
    }

    private func sky(_ scene: GardenScene) {
        if scene.isNight {
            let moon = CGMutablePath()
            moon.move(to: CGPoint(x: 15, y: 10))
            moon.addCurve(to: CGPoint(x: 15, y: 16), control1: CGPoint(x: 9, y: 10), control2: CGPoint(x: 9, y: 16))
            moon.addCurve(to: CGPoint(x: 15, y: 10), control1: CGPoint(x: 12.5, y: 15), control2: CGPoint(x: 12.5, y: 11))
            fill(moon, color: inks.accent.copy(alpha: scene.weather == .cloudy ? 0.4 : 0.8)!)
        } else if scene.weather == .clear {
            dot(13, 13, 1.8, inks.accent.copy(alpha: 0.8)!)
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3
                line([(13 + cos(angle) * 3.1, 13 + sin(angle) * 3.1),
                      (13 + cos(angle) * 3.8, 13 + sin(angle) * 3.8)], color: inks.accent, width: 0.7)
            }
        }
    }

    private func weather(_ scene: GardenScene) {
        switch scene.weather {
        case .rain, .sleet:
            drop(x: 11.5, y: 21, size: 1.35)
            drop(x: 30.5, y: 29, size: 1.1)
            line([(15, 28), (14.2, 30)], color: inks.ink.copy(alpha: 0.5)!, width: 0.7)
        case .mist:
            line([(9, 20), (15, 20)], color: inks.ink.copy(alpha: 0.3)!, width: 1)
            line([(11, 23), (17, 23)], color: inks.ink.copy(alpha: 0.22)!, width: 1)
        case .cloudy:
            line([(10, 15), (15, 15)], color: inks.accent.copy(alpha: 0.45)!, width: 1.7)
        default: break
        }
        if scene.weather == .snow || scene.weather == .sleet {
            let snow = CGMutablePath()
            snow.move(to: CGPoint(x: 16, y: 7.1))
            snow.addQuadCurve(to: CGPoint(x: 27, y: 6.8), control: CGPoint(x: 21, y: 4.8))
            stroke(snow, color: inks.accent, width: 3.2)
            stroke(snow, color: inks.snow, width: 2.4)
            dot(11, 23, 1.35, inks.accent)
            dot(11, 23, 1.0, inks.snow)
            dot(32, 28, 1.2, inks.accent)
            dot(32, 28, 0.85, inks.snow)
        }
        if scene.isWindy {
            line([(8.5, 26), (12, 26)], color: inks.accent.copy(alpha: 0.65)!, width: 0.8)
            line([(9.5, 28), (13, 28)], color: inks.accent.copy(alpha: 0.4)!, width: 0.8)
        }
    }

    private func drop(x: CGFloat, y: CGFloat, size: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y - size * 2))
        path.addCurve(to: CGPoint(x: x, y: y + size), control1: CGPoint(x: x + size * 1.6, y: y),
                      control2: CGPoint(x: x + size, y: y + size))
        path.addCurve(to: CGPoint(x: x, y: y - size * 2), control1: CGPoint(x: x - size, y: y + size),
                      control2: CGPoint(x: x - size * 1.6, y: y))
        fill(path, color: inks.ink.copy(alpha: 0.8)!)
    }

    private func ellipse(x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat, angle: Double, color: CGColor) {
        cg.saveGState()
        cg.translateBy(x: x, y: y)
        cg.rotate(by: angle * .pi / 180)
        cg.setFillColor(color)
        let rect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
        cg.fillEllipse(in: rect)
        cg.restoreGState()
    }

    private func dot(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: CGColor) {
        ellipse(x: x, y: y, rx: radius, ry: radius, angle: 0, color: color)
    }

    private func line(_ points: [(CGFloat, CGFloat)], color: CGColor, width: CGFloat) {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        stroke(path, color: color, width: width)
    }

    private func stroke(_ path: CGPath, color: CGColor, width: CGFloat) {
        cg.addPath(path)
        cg.setStrokeColor(color)
        cg.setLineWidth(width)
        cg.strokePath()
    }

    private func fill(_ path: CGPath, color: CGColor) {
        cg.addPath(path)
        cg.setFillColor(color)
        cg.fillPath()
    }
}
