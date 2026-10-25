import CoreGraphics

/// What the collapsed badge shows: whether something needs attention, and its hover text.
public struct PanelBadge: Equatable, Sendable {
    /// Width and height of the collapsed badge, in points.
    public static let size: CGFloat = 52

    public let needsAttention: Bool
    public let hint: String

    /// `weather` is a short line such as "杭州 小雨 19°", or `nil` before the weather is set up.
    public init(todaySummary: String, dueReminders: Int, weather: String? = nil) {
        needsAttention = dueReminders > 0
        let status = dueReminders > 0 ? "\(todaySummary)，有 \(dueReminders) 条提醒到时间了" : todaySummary
        hint = ([status] + [weather].compactMap { $0 } + ["点一下展开，拖动可以移动"]).joined(separator: "\n")
    }
}
