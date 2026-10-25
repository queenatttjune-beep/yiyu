import Foundation

/// A complete look for the panel: colours plus fonts.
public struct Skin: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let palette: ThemePalette
    public let fonts: ThemeFonts

    public init(id: String, name: String, palette: ThemePalette, fonts: ThemeFonts) {
        self.id = id
        self.name = name
        self.palette = palette
        self.fonts = fonts
    }

    public func with(name: String? = nil, palette: ThemePalette? = nil, fonts: ThemeFonts? = nil) -> Skin {
        Skin(id: id, name: name ?? self.name, palette: palette ?? self.palette, fonts: fonts ?? self.fonts)
    }
}

extension Skin: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, palette, fonts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "我的皮肤",
            palette: try container.decodeIfPresent(ThemePalette.self, forKey: .palette) ?? Skin.default.palette,
            fonts: try container.decodeIfPresent(ThemeFonts.self, forKey: .fonts) ?? Skin.default.fonts
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(palette, forKey: .palette)
        try container.encode(fonts, forKey: .fonts)
    }
}

/// The skins that ship with the app, named after traditional Chinese colours and papers.
/// They are never edited; changing one saves an edited copy instead (see `SkinBook`).
extension Skin {
    public static var `default`: Skin { builtIns[0] }

    public static let builtIns: [Skin] = [
        Skin(
            id: "ciqing",
            name: "磁青泥金",
            palette: palette(paper: 0x1E2B4D, field: 0x27365C, accent: 0xC8A96A, ink: 0xE9E6DC, inkMuted: 0x98A3BE, alert: 0xD0644C),
            fonts: ThemeFonts(display: "Songti SC", body: ThemeFonts.system, diary: "Songti SC")
        ),
        Skin(
            id: "zhuqing",
            name: "竹青",
            palette: palette(paper: 0x1D2E29, field: 0x273C35, accent: 0xA9CBA4, ink: 0xE6ECE3, inkMuted: 0x94AA9F, alert: 0xE07B5F),
            fonts: ThemeFonts(display: "Kaiti SC", body: ThemeFonts.system, diary: "Kaiti SC")
        ),
        Skin(
            id: "daizi",
            name: "黛紫",
            palette: palette(paper: 0x2B2438, field: 0x372E47, accent: 0xA8C8E6, ink: 0xEEE8F1, inkMuted: 0xA99CB6, alert: 0xF08A6C),
            fonts: ThemeFonts(display: "Songti SC", body: ThemeFonts.system, diary: "STFangsong")
        ),
        Skin(
            id: "xuanzhi",
            name: "宣纸",
            palette: palette(paper: 0xF2ECDF, field: 0xE6DECC, accent: 0x3F7560, ink: 0x2B2620, inkMuted: 0x766C5F, alert: 0xB4432E),
            fonts: ThemeFonts(display: "Songti SC", body: ThemeFonts.system, diary: "Kaiti SC")
        ),
        Skin(
            id: "yuebai",
            name: "月白",
            palette: palette(paper: 0xEBF0F2, field: 0xDCE4E8, accent: 0x2C5D7C, ink: 0x1E2A33, inkMuted: 0x5E6E7B, alert: 0xB9473A),
            fonts: ThemeFonts(display: "Songti SC", body: ThemeFonts.system, diary: "STFangsong")
        ),
        Skin(
            id: "ouhe",
            name: "藕荷",
            palette: palette(paper: 0xF1EAEE, field: 0xE5DAE1, accent: 0x7B4D7F, ink: 0x2E2330, inkMuted: 0x75667A, alert: 0xB8433A),
            fonts: ThemeFonts(display: "Kaiti SC", body: ThemeFonts.system, diary: "Kaiti SC")
        ),
    ]

    private static func palette(
        paper: UInt32, field: UInt32, accent: UInt32, ink: UInt32, inkMuted: UInt32, alert: UInt32
    ) -> ThemePalette {
        ThemePalette(
            paper: ThemeColor(rgb: paper),
            field: ThemeColor(rgb: field),
            accent: ThemeColor(rgb: accent),
            ink: ThemeColor(rgb: ink),
            inkMuted: ThemeColor(rgb: inkMuted),
            alert: ThemeColor(rgb: alert)
        )
    }
}
