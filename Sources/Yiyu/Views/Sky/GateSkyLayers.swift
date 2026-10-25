import QuartzCore
import YiyuCore

/// The weather seen through the badge's moon gate, as Core Animation layers on the gate's 44-point
/// drawing grid (`MoonGateMark` draws the rim and the plum branch on top): the sun or a crescent
/// moon in the empty upper left of the opening, and a handful of raindrops or snowflakes falling past.
struct GateSkyLayers {
    static let grid: CGFloat = 44
    private static let frameRate: Float = 15
    private static let opening = CGRect(x: 7, y: 7, width: 30, height: 30)
    private static let lightCenter = CGPoint(x: 14.6, y: 13.4)
    private static let stars: [(center: CGPoint, radius: CGFloat)] = [
        (CGPoint(x: 20.6, y: 10.2), 0.5),
        (CGPoint(x: 10.4, y: 17.4), 0.42),
        (CGPoint(x: 29.6, y: 27.4), 0.48),
    ]

    let scene: WeatherScene
    let colors: SkyColors
    let isAnimated: Bool
    let scale: CGFloat

    /// Scaled to fit `size` and centred, like `MoonGateMark`.
    func make(size: CGSize) -> CALayer {
        let fit = min(size.width, size.height) / Self.grid
        let detail = scale * fit
        let root = CALayer()
        root.bounds = CGRect(x: 0, y: 0, width: Self.grid, height: Self.grid)
        root.position = CGPoint(x: size.width / 2, y: size.height / 2)
        root.setAffineTransform(CGAffineTransform(scaleX: fit, y: fit))

        let mask = CAShapeLayer()
        mask.path = CGPath(ellipseIn: Self.opening, transform: nil)
        mask.contentsScale = detail
        root.mask = mask

        switch scene.sky {
        case .sun(let strength): addSun(strength, to: root, detail: detail)
        case .moon(let strength):
            root.backgroundColor = colors.accent.cgColor(alpha: 0.12)
            addMoon(strength, to: root, detail: detail)
        case .plain:
            root.backgroundColor = colors.accent.cgColor(alpha: 0.12)
        }
        if let mist = scene.mist {
            addMist(mist, to: root, detail: detail)
        }
        if let rain = scene.rain {
            root.addSublayer(SkyLayerKit.falling(
                .gateRain(rain), colors: colors.rain, in: Self.opening, scale: detail, frameRate: isAnimated ? Self.frameRate : nil
            ))
        }
        if let snow = scene.snow {
            root.addSublayer(SkyLayerKit.falling(
                .gateSnow(snow), colors: colors.snow, in: Self.opening, scale: detail, frameRate: isAnimated ? Self.frameRate : nil
            ))
        }
        return root
    }

    private func addSun(_ strength: WeatherScene.Strength, to root: CALayer, detail: CGFloat) {
        let brightness = strength == .strong ? 1.0 : 0.65
        let sun = colors.sunlight
        root.backgroundColor = sun.cgColor(alpha: 0.1 * brightness)
        root.addSublayer(SkyLayerKit.glow(in: square(around: Self.lightCenter, radius: 26), stops: [
            (0, sun.cgColor(alpha: 0.45 * brightness)),
            (0.45, sun.cgColor(alpha: 0.12 * brightness)),
            (1, sun.cgColor(alpha: 0)),
        ], scale: detail))
        let halo = SkyLayerKit.dot(at: Self.lightCenter, radius: 4.6, color: sun.cgColor(alpha: 0.3 * brightness))
        animate(halo, SkyLayerKit.swing("transform.scale", from: 0.9, to: 1.12, period: 4))
        root.addSublayer(halo)
        root.addSublayer(SkyLayerKit.dot(at: Self.lightCenter, radius: 2.7, color: sun.cgColor(alpha: 0.75 + 0.25 * brightness)))
    }

    private func addMoon(_ strength: WeatherScene.Strength, to root: CALayer, detail: CGFloat) {
        let brightness = strength == .strong ? 1.0 : 0.65
        let bite = CGPoint(x: Self.lightCenter.x + 1.5, y: Self.lightCenter.y - 1.1)
        let crescent = CAShapeLayer()
        crescent.path = SkyLayerKit.circle(at: Self.lightCenter, radius: 3).subtracting(SkyLayerKit.circle(at: bite, radius: 2.6))
        crescent.fillColor = colors.ink.cgColor(alpha: 0.9 * brightness)
        crescent.contentsScale = detail
        root.addSublayer(crescent)
        for (index, star) in Self.stars.enumerated() {
            let brightest = 0.75 * brightness
            let dot = SkyLayerKit.dot(at: star.center, radius: star.radius, color: colors.ink.cgColor(alpha: 1))
            dot.opacity = Float(brightest)
            animate(dot, SkyLayerKit.swing(
                "opacity", from: brightest * 0.2, to: brightest, period: 3 + Double(index), phase: Double(index) * 0.37
            ))
            root.addSublayer(dot)
        }
    }

    private func addMist(_ strength: WeatherScene.Strength, to root: CALayer, detail: CGFloat) {
        let density: Double = switch strength {
        case .faint: 0.35
        case .medium: 0.45
        case .strong: 0.6
        }
        let gate = Self.opening
        for band in 0..<3 {
            let center = CGPoint(x: gate.midX, y: gate.minY + gate.height * (0.3 + 0.25 * Double(band)))
            let haze = SkyLayerKit.glow(
                in: CGRect(x: center.x - 15, y: center.y - 3, width: 30, height: 6),
                stops: [(0, colors.mist.cgColor(alpha: density)), (1, colors.mist.cgColor(alpha: 0))],
                scale: detail
            )
            animate(haze, SkyLayerKit.swing(
                "position.x", from: center.x - 4, to: center.x + 4, period: 9 + 3 * Double(band), phase: Double(band) * 0.3
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
}
