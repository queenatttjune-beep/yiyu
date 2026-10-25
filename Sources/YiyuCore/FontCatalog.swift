import Foundation

public struct FontOption: Identifiable, Hashable, Sendable {
    public let family: String
    public let label: String

    public var id: String { family }
}

/// The font menu: Chinese typefaces first, under their Chinese names, then every other installed family.
public enum FontCatalog {
    /// Typefaces that come with macOS (some download on first use) or are popular free downloads.
    public static let known: [FontOption] = [
        FontOption(family: ThemeFonts.system, label: "系统字体"),
        FontOption(family: "Songti SC", label: "宋体"),
        FontOption(family: "Kaiti SC", label: "楷体"),
        FontOption(family: "STFangsong", label: "仿宋"),
        FontOption(family: "Heiti SC", label: "黑体"),
        FontOption(family: "Yuanti SC", label: "圆体"),
        FontOption(family: "Lantinghei SC", label: "兰亭黑"),
        FontOption(family: "Libian SC", label: "隶变"),
        FontOption(family: "Weibei SC", label: "魏碑"),
        FontOption(family: "Xingkai SC", label: "行楷"),
        FontOption(family: "HanziPen SC", label: "翩翩体"),
        FontOption(family: "Hannotate SC", label: "手札体"),
        FontOption(family: "Wawati SC", label: "娃娃体"),
        FontOption(family: "Yuppy SC", label: "雅痞"),
        FontOption(family: "LXGW WenKai", label: "霞鹜文楷"),
        FontOption(family: "Source Han Serif SC", label: "思源宋体"),
        FontOption(family: "Source Han Sans SC", label: "思源黑体"),
    ]

    /// The known typefaces this Mac has, system font first.
    public static func recommended(installed: Set<String>) -> [FontOption] {
        known.filter { $0.family == ThemeFonts.system || installed.contains($0.family) }
    }

    /// Installed families that are not in `known`, alphabetically, without hidden system families.
    public static func others(installed: [String]) -> [String] {
        let knownFamilies = Set(known.map(\.family))
        return Set(installed)
            .filter { !$0.hasPrefix(".") && !knownFamilies.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public static func label(for family: String) -> String {
        known.first { $0.family == family }?.label ?? family
    }
}
