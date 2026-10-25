import AppKit
import SwiftUI
import YiyuCore

/// The panel's colours and fonts, taken from the selected skin (磁青泥金 by default: indigo "磁青"
/// paper with gold "泥金" ink, after gold-ink sutra manuscripts). Reading them inside a view's `body`
/// subscribes that view to the skin, so the panel restyles itself as soon as a skin is picked or edited.
@MainActor
enum Theme {
    /// Set once at launch, before any view is built.
    static var appearance: AppearanceModel?

    static var skin: Skin { appearance?.selectedSkin ?? .default }
    private static var palette: ThemePalette { skin.palette }
    private static var fonts: ThemeFonts { skin.fonts }

    static var paper: Color { Color(palette.paper) }
    static var field: Color { Color(palette.field) }
    /// The skin's accent colour: gold in 磁青泥金.
    static var gold: Color { Color(palette.accent) }
    static var goldFaint: Color { gold.opacity(0.28) }
    static var ink: Color { Color(palette.ink) }
    static var inkMuted: Color { Color(palette.inkMuted) }
    static var inkFaint: Color { inkMuted.opacity(0.55) }
    /// Only for things that are late or due: cinnabar seal red in 磁青泥金.
    static var seal: Color { Color(palette.alert) }
    static var colorScheme: ColorScheme { palette.isDark ? .dark : .light }

    static let cornerRadius: CGFloat = 14
    static let rowInset: CGFloat = 16

    /// The skin's heading font, used for dates and titles.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        font(fonts.display, size: size, weight: weight)
    }

    static func diary(_ size: CGFloat) -> Font {
        font(fonts.diary, size: size, weight: .regular)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        font(fonts.body, size: size, weight: weight)
    }

    static var body: Font { text(13) }
    static var bodyStrong: Font { text(13, weight: .medium) }
    static var caption: Font { text(11) }

    private static func font(_ family: String, size: CGFloat, weight: Font.Weight) -> Font {
        .family(family, size: size * fonts.scale, weight: weight)
    }
}

extension Font {
    /// A family as skins name it; `ThemeFonts.system` is the system font.
    static func family(_ family: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard family != ThemeFonts.system else { return .system(size: size, weight: weight) }
        return .custom(family, fixedSize: size).weight(weight)
    }
}

extension Color {
    init(_ color: ThemeColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
    }
}

extension ThemeColor {
    /// `nil` for colours AppKit cannot express in sRGB, such as pattern colours.
    init?(_ color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
    }
}
