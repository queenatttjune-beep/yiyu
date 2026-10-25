import AppKit
import QuartzCore
import YiyuCore

/// Building blocks for the weather layers. Whatever moves is a Core Animation animation or a
/// particle emitter, so it runs in the window server and costs the app nothing between frames.
/// All geometry is top-down: the layers are meant for a root layer with flipped geometry.
enum SkyLayerKit {
    /// A soft round (or, in a wide rectangle, oval) glow filling `rect`: `stops` run from the
    /// centre (0) to the edge (1).
    static func glow(in rect: CGRect, stops: [(location: Double, color: CGColor)], scale: CGFloat) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.type = .radial
        layer.frame = rect
        layer.colors = stops.map(\.color)
        layer.locations = stops.map { NSNumber(value: $0.location) }
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.contentsScale = scale
        return layer
    }

    static func dot(at center: CGPoint, radius: CGFloat, color: CGColor) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        layer.cornerRadius = radius
        layer.backgroundColor = color
        return layer
    }

    static func circle(at center: CGPoint, radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    /// Swings `keyPath` between two values and back, easing at both ends, forever. `phase` (0...1)
    /// starts it part of the way through, so neighbours do not move in step.
    static func swing(_ keyPath: String, from: Double, to: Double, period: Double, phase: Double = 0) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = period / 2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.timeOffset = phase * period
        return animation
    }

    // MARK: - Rain and snow

    /// How drops are coloured: rain streaks in `body`; snowflakes solid `body` in the middle,
    /// fading out through `rim`, so white flakes still show on light paper.
    struct DropColors: Equatable {
        let body: ThemeColor
        let rim: ThemeColor

        init(_ body: ThemeColor, rim: ThemeColor? = nil) {
            self.body = body
            self.rim = rim ?? body
        }
    }

    /// Rain or snow falling through `area`: a particle emitter when animated, otherwise one still
    /// moment of the same drops (`PrecipitationField`).
    static func falling(
        _ style: PrecipitationField.Style, colors: DropColors, in area: CGRect, scale: CGFloat, isAnimated: Bool
    ) -> CALayer {
        isAnimated
            ? emitter(style, colors: colors, in: area, scale: scale)
            : stillDrops(style, colors: colors, in: area, scale: scale)
    }

    /// Keeps as many drops in the air as `style.density` asks for, falling at its speeds and slant.
    /// Started a full fall in the past, so the area is already full of rain when it appears.
    private static func emitter(_ style: PrecipitationField.Style, colors: DropColors, in area: CGRect, scale: CGFloat) -> CAEmitterLayer {
        let length = middle(style.length)
        let width = middle(style.width)
        let rise = length * cos(style.slant)
        let travel = Double(area.height) + rise + width
        let inTheAir = Double(area.width * area.height) / 10_000 * style.density

        let cell = CAEmitterCell()
        cell.contents = particleImage(style, colors: colors, length: length, width: width, scale: scale)
        cell.contentsScale = scale
        cell.birthRate = Float(inTheAir * middle(style.speed) / travel)
        cell.lifetime = Float(travel / style.speed.lowerBound)
        // Speeds in a style are straight down; along the slant the drop covers a little more.
        cell.velocity = middle(style.speed) / cos(style.slant)
        cell.velocityRange = halfSpan(style.speed) / cos(style.slant)
        // Core Animation measures the angle from straight up; in this top-down layer π is straight down.
        cell.emissionLongitude = .pi - style.slant
        cell.emissionRange = style.kind == .snow ? 0.12 : 0
        cell.scaleRange = halfSpan(style.kind == .rain ? style.length : style.width) / (style.kind == .rain ? length : width)
        // The image carries the colour; the cell only varies how see-through each drop is.
        cell.color = ThemeColor.white.cgColor(alpha: middle(style.opacity))
        cell.alphaRange = Float(halfSpan(style.opacity))

        let layer = CAEmitterLayer()
        layer.frame = area
        layer.masksToBounds = true
        // Wide enough that leaning drops still cover both edges on the way down.
        let drift = Double(area.height) * tan(style.slant)
        let left = min(0, -drift)
        let right = max(Double(area.width), Double(area.width) - drift)
        layer.emitterShape = .line
        layer.emitterMode = .outline
        layer.emitterPosition = CGPoint(x: (left + right) / 2, y: -rise - width)
        layer.emitterSize = CGSize(width: right - left, height: 0)
        layer.emitterCells = [cell]
        layer.beginTime = CACurrentMediaTime() - Double(cell.lifetime)
        return layer
    }

    /// One drop: a slanting streak for rain, a soft-edged flake for snow.
    private static func particleImage(
        _ style: PrecipitationField.Style, colors: DropColors, length: Double, width: Double, scale: CGFloat
    ) -> CGImage? {
        let reach = style.kind == .rain ? CGSize(width: length * sin(style.slant), height: length * cos(style.slant)) : .zero
        let size = CGSize(width: abs(reach.width) + width * 2, height: reach.height + width * 2)
        return image(size: size, scale: scale) { context in
            switch style.kind {
            case .rain:
                let tail = CGPoint(x: width + max(0, -reach.width), y: width)
                streak(in: context, from: tail, to: CGPoint(x: tail.x + reach.width, y: tail.y + reach.height),
                       width: width, color: colors.body.cgColor())
            case .snow:
                flake(in: context, at: CGPoint(x: width, y: width), diameter: width, colors: colors, alpha: 1)
            }
        }
    }

    private static func stillDrops(_ style: PrecipitationField.Style, colors: DropColors, in area: CGRect, scale: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.frame = area
        layer.contentsScale = scale
        layer.contents = image(size: area.size, scale: scale) { context in
            for drop in PrecipitationField.drops(style, in: area.size, at: 0) {
                switch style.kind {
                case .rain:
                    streak(in: context, from: drop.tail, to: drop.head, width: drop.width, color: colors.body.cgColor(alpha: drop.opacity))
                case .snow:
                    flake(in: context, at: drop.head, diameter: drop.width, colors: colors, alpha: drop.opacity)
                }
            }
        }
        return layer
    }

    private static func streak(in context: CGContext, from tail: CGPoint, to head: CGPoint, width: Double, color: CGColor) {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.move(to: tail)
        context.addLine(to: head)
        context.strokePath()
    }

    private static func flake(in context: CGContext, at center: CGPoint, diameter: Double, colors: DropColors, alpha: Double) {
        let stops = [colors.body.cgColor(alpha: alpha), colors.rim.cgColor(alpha: alpha * 0.7), colors.rim.cgColor(alpha: 0)]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops as CFArray, locations: [0, 0.5, 1]
        ) else { return }
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: diameter / 2, options: [])
    }

    /// A transparent image `size` points across, drawn top-down by `draw`.
    private static func image(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
        let pixelsWide = Int((size.width * scale).rounded(.up))
        let pixelsHigh = Int((size.height * scale).rounded(.up))
        guard pixelsWide > 0, pixelsHigh > 0, let context = CGContext(
            data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(pixelsHigh))
        context.scaleBy(x: scale, y: -scale)
        draw(context)
        return context.makeImage()
    }

    private static func middle(_ range: ClosedRange<Double>) -> Double {
        (range.lowerBound + range.upperBound) / 2
    }

    private static func halfSpan(_ range: ClosedRange<Double>) -> Double {
        (range.upperBound - range.lowerBound) / 2
    }
}
