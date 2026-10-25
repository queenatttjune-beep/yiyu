import QuartzCore
import YiyuCore

/// The weather behind the expanded panel, as Core Animation layers: a warm glow and slow shafts of
/// light from the top-right corner (where the temperature is) on a clear day, moonlight and
/// twinkling stars on a clear night, drifting mist, and rain or snow that thins out toward the
/// bottom so the list stays easy to read.
struct PanelSkyLayers {
    private static let rayCount = 7
    private static let starCount = 16
    /// How much of the rain and snow the paper veils at the bottom edge.
    private static let bottomVeil = 0.55
    private static let rainFrameRate: Float = 24
    private static let snowFrameRate: Float = 20

    let scene: WeatherScene
    let colors: SkyColors
    let isAnimated: Bool
    let scale: CGFloat

    func make(size: CGSize) -> CALayer {
        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: size)
        let corner = CGPoint(x: size.width - 30, y: -8)
        switch scene.sky {
        case .sun(let strength): addSun(strength, at: corner, to: root)
        case .moon(let strength): addMoon(strength, at: corner, to: root, size: size)
        case .plain: break
        }
        let bounds = CGRect(origin: .zero, size: size)
        if let rain = scene.rain {
            root.addSublayer(SkyLayerKit.falling(
                .rain(rain), colors: colors.rain, in: bounds, scale: scale, frameRate: isAnimated ? Self.rainFrameRate : nil
            ))
        }
        if let snow = scene.snow {
            root.addSublayer(SkyLayerKit.falling(
                .snow(snow), colors: colors.snow, in: bounds, scale: scale, frameRate: isAnimated ? Self.snowFrameRate : nil
            ))
        }
        if scene.rain != nil || scene.snow != nil {
            root.addSublayer(SkyLayerKit.veil(colors.paper, in: bounds, bottomOpacity: Self.bottomVeil))
        }
        if let mist = scene.mist {
            addMist(mist, to: root, size: size)
        }
        return root
    }

    // MARK: - Light

    /// A warm glow that breathes slowly, and a few soft shafts of light swaying out of the corner.
    private func addSun(_ strength: WeatherScene.Strength, at corner: CGPoint, to root: CALayer) {
        let brightness = strength == .strong ? 1.0 : 0.6
        let sun = colors.sunlight
        let glow = SkyLayerKit.glow(in: square(around: corner, radius: 320), stops: [
            (0, sun.cgColor(alpha: 0.4 * brightness)),
            (0.35, sun.cgColor(alpha: 0.15 * brightness)),
            (1, sun.cgColor(alpha: 0)),
        ], scale: scale)
        animate(glow, SkyLayerKit.swing("transform.scale", from: 0.94, to: 1.06, period: 7))
        root.addSublayer(glow)

        // Two fans of rays swaying at different paces look less mechanical than one.
        for fan in 0..<2 {
            let fanLayer = rays(Array(stride(from: fan, to: Self.rayCount, by: 2)), from: corner, brightness: brightness)
            animate(fanLayer, SkyLayerKit.swing(
                "transform.rotation.z", from: -0.035, to: 0.035, period: fan == 0 ? 23 : 31, phase: fan == 0 ? 0 : 0.4
            ))
            root.addSublayer(fanLayer)
        }
    }

    /// Soft shafts of light fanning out of `corner`, drawn once into a single image that turns
    /// about the corner.
    private func rays(_ indices: [Int], from corner: CGPoint, brightness: Double) -> CALayer {
        let wedges = indices.map { index -> (path: CGPath, length: Double) in
            let length = 380 + 180 * Scatter.unit(index, salt: 11)
            let spread = (1.4 + 1.6 * Scatter.unit(index, salt: 12)) * .pi / 180
            let angle = (102 + Double(index) * 16) * .pi / 180
            let wedge = CGMutablePath()
            wedge.move(to: corner)
            wedge.addLine(to: point(from: corner, angle: angle - spread, distance: length))
            wedge.addLine(to: point(from: corner, angle: angle + spread, distance: length))
            wedge.closeSubpath()
            return (wedge, length)
        }
        let frame = wedges.reduce(CGRect(origin: corner, size: .zero)) { $0.union($1.path.boundingBox) }
        let shaft = [colors.sunlight.cgColor(alpha: 0.1 * brightness), colors.sunlight.cgColor(alpha: 0)] as CFArray
        let layer = CALayer()
        layer.frame = frame
        layer.anchorPoint = CGPoint(x: (corner.x - frame.minX) / frame.width, y: (corner.y - frame.minY) / frame.height)
        layer.position = corner
        // Soft light needs no Retina detail, and one point per pixel keeps the image small.
        layer.contentsScale = 1
        layer.contents = SkyLayerKit.image(size: frame.size, scale: 1) { context in
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: shaft, locations: [0, 1]) else { return }
            context.translateBy(x: -frame.minX, y: -frame.minY)
            for wedge in wedges {
                context.saveGState()
                context.addPath(wedge.path)
                context.clip()
                context.drawRadialGradient(gradient, startCenter: corner, startRadius: 0, endCenter: corner, endRadius: wedge.length, options: [])
                context.restoreGState()
            }
        }
        return layer
    }

    /// Cool moonlight in the corner and a scatter of stars twinkling across the top of the panel.
    private func addMoon(_ strength: WeatherScene.Strength, at corner: CGPoint, to root: CALayer, size: CGSize) {
        let brightness = strength == .strong ? 1.0 : 0.6
        root.addSublayer(SkyLayerKit.glow(in: square(around: corner, radius: 230), stops: [
            (0, colors.moonlight.cgColor(alpha: 0.13 * brightness)),
            (1, colors.moonlight.cgColor(alpha: 0)),
        ], scale: scale))
        guard let starColor = colors.stars else { return }
        for index in 0..<Self.starCount {
            let center = CGPoint(
                x: Scatter.unit(index, salt: 21) * size.width,
                y: Scatter.unit(index, salt: 22) * size.height * 0.42
            )
            let radius = 0.5 + 0.6 * Scatter.unit(index, salt: 23)
            let brightest = (0.25 + 0.35 * Scatter.unit(index, salt: 26)) * brightness
            let star = SkyLayerKit.dot(at: center, radius: radius, color: starColor.cgColor(alpha: 1))
            star.opacity = Float(brightest)
            animate(star, SkyLayerKit.swing(
                "opacity", from: brightest * 0.15, to: brightest,
                period: 4 + 6 * Scatter.unit(index, salt: 24), phase: Scatter.unit(index, salt: 25)
            ))
            root.addSublayer(star)
        }
    }

    // MARK: - Weather

    /// Three wide, soft bands of mist drifting slowly side to side.
    private func addMist(_ strength: WeatherScene.Strength, to root: CALayer, size: CGSize) {
        let density: Double = switch strength {
        case .faint: 0.10
        case .medium: 0.16
        case .strong: 0.24
        }
        for band in 0..<3 {
            let height = 110 + 50 * Scatter.unit(band, salt: 31)
            let width = size.width * 1.8
            let center = CGPoint(x: size.width / 2, y: size.height * (0.16 + 0.3 * Double(band)))
            let haze = SkyLayerKit.glow(
                in: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height),
                stops: [(0, colors.mist.cgColor(alpha: density)), (1, colors.mist.cgColor(alpha: 0))],
                scale: scale
            )
            let sway = size.width * 0.25
            animate(haze, SkyLayerKit.swing(
                "position.x", from: center.x - sway, to: center.x + sway,
                period: 40 + 12 * Double(band), phase: Double(band) * 0.3
            ))
            root.addSublayer(haze)
        }
    }

    private func animate(_ layer: CALayer, _ animation: CABasicAnimation) {
        guard isAnimated, let keyPath = animation.keyPath else { return }
        layer.add(animation, forKey: keyPath)
    }

    private func square(around center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private func point(from origin: CGPoint, angle: Double, distance: Double) -> CGPoint {
        CGPoint(x: origin.x + cos(angle) * distance, y: origin.y + sin(angle) * distance)
    }
}
