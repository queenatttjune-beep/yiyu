import CoreGraphics
import YiyuCore

/// The colours the weather is painted in, taken from the skin: rain and mist in the text colours
/// (light streaks on dark paper, pencil grey on light paper), snow white with a grey rim on light
/// paper, sunlight always warm, and a dusky corner instead of moonlight on light paper.
struct SkyColors: Equatable {
    private static let paleSun = ThemeColor(rgb: 0xF7C973)
    private static let deepSun = ThemeColor(rgb: 0xF2A63D)

    let rain: SkyLayerKit.DropColors
    let snow: SkyLayerKit.DropColors
    let mist: ThemeColor
    let moonlight: ThemeColor
    /// `nil` on light paper, where dark stars would read as specks of dust.
    let stars: ThemeColor?
    let sunlight: ThemeColor
    let paper: ThemeColor
    /// The badge's own colours: the quiet light in its opening, and the ink of its blossoms.
    let accent: ThemeColor
    let ink: ThemeColor

    /// Read inside a view's `body`, so a change of skin repaints the weather.
    @MainActor static var current: SkyColors {
        let palette = Theme.skin.palette
        let isDark = palette.isDark
        return SkyColors(
            rain: SkyLayerKit.DropColors(isDark ? palette.ink : palette.inkMuted),
            snow: isDark ? SkyLayerKit.DropColors(palette.ink) : SkyLayerKit.DropColors(.white, rim: palette.inkMuted),
            mist: isDark ? palette.ink : palette.inkMuted,
            moonlight: isDark ? palette.ink : palette.inkMuted,
            stars: isDark ? palette.ink : nil,
            sunlight: isDark ? paleSun : deepSun,
            paper: palette.paper,
            accent: palette.accent,
            ink: palette.ink
        )
    }
}

extension ThemeColor {
    func cgColor(alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
