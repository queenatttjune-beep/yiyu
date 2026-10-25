import Foundation

/// An opaque sRGB colour. Stored in JSON as `"#RRGGBB"` so skin files stay readable.
public struct ThemeColor: Hashable, Sendable {
    public static let black = ThemeColor(rgb: 0x000000)
    public static let white = ThemeColor(rgb: 0xFFFFFF)

    /// `0xRRGGBB`.
    public let rgb: UInt32

    public init(rgb: UInt32) {
        self.rgb = rgb & 0xFFFFFF
    }

    /// Accepts `#RRGGBB` or `RRGGBB` in either case; surrounding spaces are ignored.
    public init?(hex: String) {
        var digits = Substring(hex.trimmingCharacters(in: .whitespaces))
        if digits.hasPrefix("#") {
            digits = digits.dropFirst()
        }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(rgb: value)
    }

    /// Components from 0 to 1; out-of-range values are clamped.
    public init(red: Double, green: Double, blue: Double) {
        func byte(_ component: Double) -> UInt32 {
            guard component.isFinite else { return 0 }
            return UInt32((min(max(component, 0), 1) * 255).rounded())
        }
        self.init(rgb: byte(red) << 16 | byte(green) << 8 | byte(blue))
    }

    public var hex: String { String(format: "#%06X", rgb) }

    public var red: Double { Double((rgb >> 16) & 0xFF) / 255 }
    public var green: Double { Double((rgb >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(rgb & 0xFF) / 255 }

    /// WCAG 2 relative luminance: 0 for black, 1 for white.
    public var relativeLuminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// WCAG 2 contrast ratio, from 1 (identical) to 21 (black on white).
    public func contrastRatio(with other: ThemeColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func linear(_ component: Double) -> Double {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }
}

extension ThemeColor: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let color = ThemeColor(hex: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a #RRGGBB colour: \(text)")
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
