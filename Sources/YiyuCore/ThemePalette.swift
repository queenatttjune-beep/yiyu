import Foundation

/// What each colour of a skin is used for.
public enum ColorRole: String, CaseIterable, CodingKey, Sendable {
    case paper
    case field
    case accent
    case ink
    case inkMuted
    case alert

    public var label: String {
        switch self {
        case .paper: "底色"
        case .field: "输入框"
        case .accent: "点缀色"
        case .ink: "文字"
        case .inkMuted: "次要文字"
        case .alert: "提醒色"
        }
    }

    public var detail: String {
        switch self {
        case .paper: "面板的纸色"
        case .field: "输入框和鼠标经过时的底色"
        case .accent: "日期、勾选和当前页签"
        case .ink: "待办、备忘和日记正文"
        case .inkMuted: "说明、时间和提示文字"
        case .alert: "逾期和到点的事项"
        }
    }

    /// The contrast this colour needs against the paper and the input field; `nil` for backgrounds.
    /// Body text follows WCAG AA (4.5), everything else the large-text and graphics level (3).
    public var minimumContrast: Double? {
        switch self {
        case .paper, .field: nil
        case .ink: 4.5
        case .accent, .inkMuted, .alert: 3
        }
    }
}

public struct ThemePalette: Hashable, Sendable {
    public let paper: ThemeColor
    public let field: ThemeColor
    public let accent: ThemeColor
    public let ink: ThemeColor
    public let inkMuted: ThemeColor
    public let alert: ThemeColor

    public init(
        paper: ThemeColor,
        field: ThemeColor,
        accent: ThemeColor,
        ink: ThemeColor,
        inkMuted: ThemeColor,
        alert: ThemeColor
    ) {
        self.paper = paper
        self.field = field
        self.accent = accent
        self.ink = ink
        self.inkMuted = inkMuted
        self.alert = alert
    }

    public subscript(role: ColorRole) -> ThemeColor {
        switch role {
        case .paper: paper
        case .field: field
        case .accent: accent
        case .ink: ink
        case .inkMuted: inkMuted
        case .alert: alert
        }
    }

    public func with(_ role: ColorRole, _ color: ThemeColor) -> ThemePalette {
        ThemePalette(
            paper: role == .paper ? color : paper,
            field: role == .field ? color : field,
            accent: role == .accent ? color : accent,
            ink: role == .ink ? color : ink,
            inkMuted: role == .inkMuted ? color : inkMuted,
            alert: role == .alert ? color : alert
        )
    }

    /// Dark paper wants light system controls: true when white reads better on it than black.
    public var isDark: Bool {
        paper.contrastRatio(with: .white) >= paper.contrastRatio(with: .black)
    }

    /// Colours that sit too close to the paper or the input field to read comfortably.
    public var hardToReadRoles: [ColorRole] {
        ColorRole.allCases.filter { role in
            guard let minimum = role.minimumContrast else { return false }
            let color = self[role]
            return min(color.contrastRatio(with: paper), color.contrastRatio(with: field)) < minimum
        }
    }
}

extension ThemePalette: Codable {
    /// Roles missing from the file (written by an older version) or mistyped by hand keep the
    /// default skin's colour, so one bad value never costs the whole skin.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ColorRole.self)
        var palette = Skin.default.palette
        for role in ColorRole.allCases {
            if let color = try? container.decodeIfPresent(ThemeColor.self, forKey: role) {
                palette = palette.with(role, color)
            }
        }
        self = palette
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ColorRole.self)
        for role in ColorRole.allCases {
            try container.encode(self[role], forKey: role)
        }
    }
}
