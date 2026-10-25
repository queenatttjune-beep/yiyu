import SwiftUI

/// 磁青泥金: indigo "磁青" paper with gold "泥金" ink, after gold-ink sutra manuscripts.
enum Theme {
    static let paper = Color(hex: 0x1E2B4D)
    static let paperDeep = Color(hex: 0x16203B)
    static let field = Color(hex: 0x27365C)
    static let gold = Color(hex: 0xC8A96A)
    static let goldFaint = Color(hex: 0xC8A96A).opacity(0.28)
    static let ink = Color(hex: 0xE9E6DC)
    static let inkMuted = Color(hex: 0x98A3BE)
    static let inkFaint = Color(hex: 0x98A3BE).opacity(0.55)
    /// Cinnabar seal red, only for things that are late or due.
    static let seal = Color(hex: 0xD0644C)

    static let cornerRadius: CGFloat = 14
    static let rowInset: CGFloat = 16

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Songti SC", size: size).weight(weight)
    }

    static let body = Font.system(size: 13)
    static let bodyStrong = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
