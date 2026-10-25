import Foundation

/// Where each font of a skin is used.
public enum FontRole: String, CaseIterable, CodingKey, Sendable {
    case display
    case body
    case diary

    public var label: String {
        switch self {
        case .display: "标题字体"
        case .body: "正文字体"
        case .diary: "日记字体"
        }
    }

    public var detail: String {
        switch self {
        case .display: "日期和标题"
        case .body: "列表、按钮和备忘"
        case .diary: "日记正文"
        }
    }
}

public enum TextSize: CaseIterable, Sendable {
    case small
    case standard
    case large
    case extraLarge

    public var scale: Double {
        switch self {
        case .small: 0.92
        case .standard: 1
        case .large: 1.08
        case .extraLarge: 1.16
        }
    }

    public var label: String {
        switch self {
        case .small: "小"
        case .standard: "标准"
        case .large: "大"
        case .extraLarge: "特大"
        }
    }

    public init(nearest scale: Double) {
        self = Self.allCases.min { abs($0.scale - scale) < abs($1.scale - scale) } ?? .standard
    }
}

/// Font family names as `NSFontManager` lists them; `system` means the system font (PingFang for Chinese).
public struct ThemeFonts: Hashable, Sendable {
    public static let system = ""
    public static let scaleRange: ClosedRange<Double> = 0.85...1.25

    public let display: String
    public let body: String
    public let diary: String
    /// Multiplies every text size in the panel.
    public let scale: Double

    public init(display: String, body: String, diary: String, scale: Double = 1) {
        self.display = display
        self.body = body
        self.diary = diary
        self.scale = scale.isFinite ? min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound) : 1
    }

    public subscript(role: FontRole) -> String {
        switch role {
        case .display: display
        case .body: body
        case .diary: diary
        }
    }

    public func with(_ role: FontRole, _ family: String) -> ThemeFonts {
        ThemeFonts(
            display: role == .display ? family : display,
            body: role == .body ? family : body,
            diary: role == .diary ? family : diary,
            scale: scale
        )
    }

    public func with(scale: Double) -> ThemeFonts {
        ThemeFonts(display: display, body: body, diary: diary, scale: scale)
    }
}

extension ThemeFonts: Codable {
    private enum CodingKeys: String, CodingKey {
        case display, body, diary, scale
    }

    /// Missing or mistyped fields keep the default skin's value.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Skin.default.fonts
        func family(_ key: CodingKeys, _ defaultValue: String) -> String {
            (try? container.decodeIfPresent(String.self, forKey: key)) ?? defaultValue
        }
        self.init(
            display: family(.display, fallback.display),
            body: family(.body, fallback.body),
            diary: family(.diary, fallback.diary),
            scale: (try? container.decodeIfPresent(Double.self, forKey: .scale)) ?? fallback.scale
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(display, forKey: .display)
        try container.encode(body, forKey: .body)
        try container.encode(diary, forKey: .diary)
        try container.encode(scale, forKey: .scale)
    }
}
