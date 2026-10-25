import CoreGraphics
import Foundation

/// Spreads things evenly but irregularly: the same index and salt always give the same value in
/// 0..<1 (a splitmix64 hash), so a drawing can be worked out from the clock without keeping state.
public enum Scatter {
    public static func unit(_ index: Int, salt: UInt64) -> Double {
        var bits = UInt64(bitPattern: Int64(index)) &* 0x9E37_79B9_7F4A_7C15 &+ salt &* 0xD1B5_4A32_D192_ED03
        bits = (bits ^ (bits >> 30)) &* 0xBF58_476D_1CE4_E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D0_49BB_1331_11EB
        bits ^= bits >> 31
        return Double(bits >> 11) / Double(UInt64(1) << 53)
    }

    public static func value(in range: ClosedRange<Double>, _ index: Int, salt: UInt64) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit(index, salt: salt)
    }
}

/// Raindrops or snowflakes falling through an area. Each drop's place follows from the clock
/// alone: the same style, size and time always give the same drops, and a drop that falls out at
/// the bottom comes back in at the top.
public enum PrecipitationField {
    public enum Kind: Sendable {
        case rain, snow
    }

    public struct Style: Equatable, Sendable {
        public let kind: Kind
        /// Drops per 10,000 square points.
        public let density: Double
        /// Points per second, straight down.
        public let speed: ClosedRange<Double>
        /// Length of a rain streak; zero for snow.
        public let length: ClosedRange<Double>
        /// Line width of a streak, or the diameter of a flake.
        public let width: ClosedRange<Double>
        public let opacity: ClosedRange<Double>
        /// Lean from the vertical in radians; positive drifts right on the way down.
        public let slant: Double
        /// How far a snowflake swings to either side, in points.
        public let sway: Double

        public init(
            kind: Kind, density: Double, speed: ClosedRange<Double>, length: ClosedRange<Double>,
            width: ClosedRange<Double>, opacity: ClosedRange<Double>, slant: Double, sway: Double = 0
        ) {
            self.kind = kind
            self.density = density
            self.speed = speed
            self.length = length
            self.width = width
            self.opacity = opacity
            self.slant = slant
            self.sway = sway
        }
    }

    public struct Drop: Equatable, Sendable {
        /// The lower, leading end.
        public let head: CGPoint
        /// The upper end; the same point as `head` for a snowflake.
        public let tail: CGPoint
        public let width: CGFloat
        public let opacity: Double
    }

    private static let swayRate: ClosedRange<Double> = 0.5...1.1

    public static func drops(_ style: Style, in size: CGSize, at time: TimeInterval) -> [Drop] {
        guard size.width > 0, size.height > 0 else { return [] }
        let count = Int((Double(size.width * size.height) / 10_000 * style.density).rounded())
        return (0..<count).map { drop($0, style: style, size: size, time: time) }
    }

    private static func drop(_ index: Int, style: Style, size: CGSize, time: TimeInterval) -> Drop {
        let width = Double(size.width)
        let height = Double(size.height)
        let length = Scatter.value(in: style.length, index, salt: 1)
        let thickness = Scatter.value(in: style.width, index, salt: 2)
        let speed = Scatter.value(in: style.speed, index, salt: 3)

        // The head runs from the top edge until the whole drop has left the bottom.
        let rise = length * cos(style.slant)
        let travel = height + rise + thickness
        let progress = Scatter.unit(index, salt: 4) + time * speed / travel
        let fallen = (progress - progress.rounded(.down)) * travel

        // Spread the starting points wide enough that leaning drops still cover both edges.
        let drift = height * tan(style.slant)
        let start = Scatter.value(in: min(0, -drift)...max(width, width - drift), index, salt: 5)
        var x = start + fallen * tan(style.slant)
        if style.sway > 0 {
            let rate = Scatter.value(in: swayRate, index, salt: 6)
            x += sin(time * rate + Scatter.unit(index, salt: 7) * 2 * .pi) * style.sway
        }

        let head = CGPoint(x: x, y: fallen)
        let tail = CGPoint(x: x - length * sin(style.slant), y: fallen - rise)
        return Drop(
            head: head, tail: tail, width: thickness,
            opacity: Scatter.value(in: style.opacity, index, salt: 8)
        )
    }
}

extension PrecipitationField.Style {
    /// Rain over the panel, blown in from the right like the rain in the weather symbols. Even the
    /// strongest stays thin lines; the faint one is the misty drizzle.
    public static func rain(_ strength: WeatherScene.Strength) -> Self {
        switch strength {
        case .faint:
            Self(kind: .rain, density: 4.2, speed: 80...125, length: 7...12, width: 0.55...0.85, opacity: 0.18...0.36, slant: -0.2)
        case .medium:
            Self(kind: .rain, density: 6.5, speed: 170...240, length: 10...17, width: 0.6...0.95, opacity: 0.2...0.38, slant: -0.16)
        case .strong:
            Self(kind: .rain, density: 10, speed: 300...400, length: 15...24, width: 0.7...1.1, opacity: 0.22...0.42, slant: -0.12)
        }
    }

    public static func snow(_ strength: WeatherScene.Strength) -> Self {
        switch strength {
        case .faint:
            Self(kind: .snow, density: 2.4, speed: 14...24, length: 0...0, width: 3.5...5.5, opacity: 0.5...0.85, slant: 0.06, sway: 7)
        case .medium:
            Self(kind: .snow, density: 4, speed: 18...30, length: 0...0, width: 4...6.5, opacity: 0.5...0.9, slant: 0.08, sway: 8)
        case .strong:
            Self(kind: .snow, density: 6.5, speed: 24...40, length: 0...0, width: 4.5...7, opacity: 0.55...0.95, slant: 0.1, sway: 9)
        }
    }

    /// Rain seen through the badge's moon gate, on its 44-point drawing grid: a handful of short drops.
    public static func gateRain(_ strength: WeatherScene.Strength) -> Self {
        switch strength {
        case .faint:
            Self(kind: .rain, density: 95, speed: 9...14, length: 2.4...3.6, width: 0.6...0.75, opacity: 0.6...0.85, slant: -0.22)
        case .medium:
            Self(kind: .rain, density: 140, speed: 16...22, length: 3...4.4, width: 0.6...0.75, opacity: 0.6...0.85, slant: -0.18)
        case .strong:
            Self(kind: .rain, density: 200, speed: 26...34, length: 3.8...5.4, width: 0.65...0.8, opacity: 0.65...0.9, slant: -0.14)
        }
    }

    public static func gateSnow(_ strength: WeatherScene.Strength) -> Self {
        switch strength {
        case .faint:
            Self(kind: .snow, density: 70, speed: 2.2...3.4, length: 0...0, width: 1.5...2.3, opacity: 0.7...0.95, slant: 0.05, sway: 1.2)
        case .medium:
            Self(kind: .snow, density: 100, speed: 2.8...4.2, length: 0...0, width: 1.6...2.5, opacity: 0.7...0.95, slant: 0.06, sway: 1.2)
        case .strong:
            Self(kind: .snow, density: 140, speed: 3.6...5.2, length: 0...0, width: 1.7...2.7, opacity: 0.75...1, slant: 0.08, sway: 1.3)
        }
    }
}
