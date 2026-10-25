import AppKit
import QuartzCore
import YiyuCore

/// Building blocks for the weather layers. Whatever moves is a Core Animation animation capped at a
/// low frame rate, so it costs the app nothing between frames and the window server little.
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

    /// Slow swings look the same at 20 frames a second and spare the window server a full-rate redraw.
    private static let slowFrameRate = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 20)

    /// Swings `keyPath` between two values and back, easing at both ends, forever. `phase` (0...1)
    /// starts it part of the way through, so neighbours do not move in step.
    static func swing(_ keyPath: String, from: Double, to: Double, period: Double, phase: Double = 0) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.preferredFrameRateRange = slowFrameRate
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

    private static let sheetCount = 2

    /// Rain or snow falling through `area`. The drops (`PrecipitationField`) are drawn once onto a
    /// couple of seamless sheets, each sliding down at its own speed for depth, at most `frameRate`
    /// times a second: a full-rate particle emitter kept the window server three times as busy.
    /// With `frameRate` nil the sheets stand still.
    static func falling(
        _ style: PrecipitationField.Style, colors: DropColors, in area: CGRect, scale: CGFloat, frameRate: Float?
    ) -> CALayer {
        let holder = CALayer()
        holder.frame = area
        holder.masksToBounds = true
        let drops = PrecipitationField.drops(style, in: area.size, at: 0)
        for index in 0..<sheetCount {
            let share = drops.enumerated().filter { $0.offset % sheetCount == index }.map(\.element)
            let pace = (Double(index) + 0.5) / Double(sheetCount)
            let speed = style.speed.lowerBound + (style.speed.upperBound - style.speed.lowerBound) * pace
            holder.addSublayer(sheet(
                share, style: style, colors: colors, size: area.size, scale: scale, speed: speed,
                frameRate: frameRate, phase: pace
            ))
        }
        return holder
    }

    /// Tiles of one sheet image covering the area, moved one tile down (and sideways along the
    /// slant) per loop; the image wraps around at its edges, so the loop never shows a seam.
    private static func sheet(
        _ drops: [PrecipitationField.Drop], style: PrecipitationField.Style, colors: DropColors,
        size: CGSize, scale: CGFloat, speed: Double, frameRate: Float?, phase: Double
    ) -> CALayer {
        let drift = Double(size.height) * tan(style.slant)
        let picture = image(size: size, scale: scale) { context in
            for drop in drops {
                for row in -1...1 {
                    for column in -1...1 {
                        let shift = CGPoint(x: Double(column) * size.width + Double(row) * drift, y: Double(row) * size.height)
                        draw(drop, shiftedBy: shift, style: style, colors: colors, in: context)
                    }
                }
            }
        }
        let tiles = CALayer()
        tiles.frame = CGRect(origin: .zero, size: size)
        for row in -1...0 {
            for column in -1...1 {
                let tile = CALayer()
                tile.frame = CGRect(
                    x: Double(column) * size.width + Double(row) * drift, y: Double(row) * size.height,
                    width: size.width, height: size.height
                )
                tile.contents = picture
                tile.contentsScale = scale
                tiles.addSublayer(tile)
            }
        }
        guard let frameRate else { return tiles }
        let range = CAFrameRateRange(minimum: frameRate / 2, maximum: frameRate, preferred: frameRate)
        let fall = CABasicAnimation(keyPath: "position")
        fall.byValue = NSValue(point: CGPoint(x: drift, y: size.height))
        fall.isAdditive = true
        fall.duration = Double(size.height) / speed
        fall.repeatCount = .infinity
        fall.timingFunction = CAMediaTimingFunction(name: .linear)
        fall.timeOffset = phase * fall.duration
        fall.preferredFrameRateRange = range
        tiles.add(fall, forKey: "fall")
        if style.sway > 0 {
            let sway = CABasicAnimation(keyPath: "position.x")
            sway.fromValue = -style.sway
            sway.toValue = style.sway
            sway.isAdditive = true
            sway.duration = 3 + 2 * phase
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sway.preferredFrameRateRange = range
            tiles.add(sway, forKey: "sway")
        }
        return tiles
    }

    private static func draw(
        _ drop: PrecipitationField.Drop, shiftedBy shift: CGPoint, style: PrecipitationField.Style,
        colors: DropColors, in context: CGContext
    ) {
        let head = CGPoint(x: drop.head.x + shift.x, y: drop.head.y + shift.y)
        switch style.kind {
        case .rain:
            let tail = CGPoint(x: drop.tail.x + shift.x, y: drop.tail.y + shift.y)
            streak(in: context, from: tail, to: head, width: drop.width, color: colors.body.cgColor(alpha: drop.opacity))
        case .snow:
            flake(in: context, at: head, diameter: drop.width, colors: colors, alpha: drop.opacity)
        }
    }

    /// A veil of `color` thickening toward the bottom, laid over rain or snow to thin it out there
    /// (cheaper than a mask, which the window server would redo every frame).
    static func veil(_ color: ThemeColor, in area: CGRect, bottomOpacity: Double) -> CALayer {
        let layer = CALayer()
        layer.frame = area
        layer.contentsGravity = .resize
        layer.contents = image(size: CGSize(width: 1, height: 64), scale: 1) { context in
            let colors = [color.cgColor(alpha: 0), color.cgColor(alpha: bottomOpacity)] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) else { return }
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 64), options: [])
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
    static func image(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
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
