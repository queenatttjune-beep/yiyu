import SwiftUI

/// A garden moon gate with a plum branch slanting in through it: the round badge is the gate, and
/// inside it a small world. Drawn on a 44 × 44 grid and scaled to fit, in the skin's own colours.
/// When there is weather to show, `GateSky` paints the opening underneath instead of the moonlight.
struct MoonGateMark: View {
    private static let grid: CGFloat = 44
    private static let center = CGPoint(x: 22, y: 22)
    private static let gateRadius: CGFloat = 15
    private static let ringWidth: CGFloat = 1.5

    private static let trunk = polyline([(5, 35.2), (11, 31.4), (14.6, 27.4), (20.4, 24.6)])
    private static let bough = polyline([(20.4, 24.6), (23.8, 20), (31.6, 16.2)])
    private static let twigs = [polyline([(14.6, 27.4), (13.8, 23.8)]), polyline([(23.8, 20), (23.4, 17)])]
    private static let blossoms: [(center: CGPoint, size: CGFloat)] = [
        (CGPoint(x: 13.6, y: 21.8), 3.2),
        (CGPoint(x: 23.3, y: 14.6), 3.6),
    ]
    private static let buds: [(center: CGPoint, radius: CGFloat)] = [
        (CGPoint(x: 31.9, y: 15.9), 1.25),
        (CGPoint(x: 27.6, y: 18.2), 1),
    ]

    var drawsMoonlight = true

    var body: some View {
        // Read the colours here rather than inside the canvas, so a change of skin redraws the mark.
        let colors = Colors(paper: Theme.paper, accent: Theme.gold, ink: Theme.ink)
        let drawsMoonlight = drawsMoonlight
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.grid
            context.translateBy(
                x: (size.width - Self.grid * scale) / 2,
                y: (size.height - Self.grid * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            Self.draw(in: &context, colors: colors, drawsMoonlight: drawsMoonlight)
        }
        .accessibilityHidden(true)
    }

    private struct Colors {
        let paper: Color
        let accent: Color
        let ink: Color
    }

    private static func draw(in context: inout GraphicsContext, colors: Colors, drawsMoonlight: Bool) {
        let accent = GraphicsContext.Shading.color(colors.accent)
        let gate = Path(ellipseIn: CGRect(
            x: center.x - gateRadius, y: center.y - gateRadius, width: gateRadius * 2, height: gateRadius * 2
        ))

        // Moonlight in the opening, then the gate's rim.
        if drawsMoonlight {
            context.fill(gate, with: .color(colors.accent.opacity(0.12)))
        }
        context.stroke(gate, with: accent, lineWidth: ringWidth)

        // Where the trunk crosses the rim, part the rim so the branch reads as passing in front of it.
        context.drawLayer { layer in
            var band = Path(ellipseIn: gate.boundingRect.insetBy(dx: -2, dy: -2))
            band.addPath(Path(ellipseIn: gate.boundingRect.insetBy(dx: 2, dy: 2)))
            layer.clip(to: band, style: FillStyle(eoFill: true))
            layer.stroke(trunk, with: .color(colors.paper), style: round(5))
        }

        context.stroke(trunk, with: accent, style: round(2.3))
        context.stroke(bough, with: accent, style: round(1.6))
        for twig in twigs {
            context.stroke(twig, with: accent, style: round(1.1))
        }
        for blossom in blossoms {
            context.fill(petals(at: blossom.center, size: blossom.size), with: .color(colors.ink))
            context.fill(circle(at: blossom.center, radius: 0.75), with: accent)
        }
        for bud in buds {
            context.fill(circle(at: bud.center, radius: bud.radius), with: .color(colors.ink))
        }
    }

    /// A five-petalled plum blossom, one petal pointing up.
    private static func petals(at center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        for index in 0..<5 {
            let angle = (-90 + Double(index) * 72) * .pi / 180
            let petal = CGPoint(x: center.x + cos(angle) * size * 0.6, y: center.y + sin(angle) * size * 0.6)
            path.addPath(circle(at: petal, radius: size * 0.44))
        }
        return path
    }

    private static func circle(at center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func polyline(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
        return path
    }

    private static func round(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}
