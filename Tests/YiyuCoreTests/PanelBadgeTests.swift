import CoreGraphics
import Testing
@testable import YiyuCore

struct PanelBadgeTests {
    @Test func calmWhenNothingIsDue() {
        let badge = PanelBadge(todaySummary: "今天还有 3 件事", dueReminders: 0)
        #expect(badge.needsAttention == false)
        #expect(badge.hint == "今天还有 3 件事\n点一下展开，拖动可以移动")
    }

    @Test func dueRemindersAskForAttentionAndAreNamedInTheHint() {
        let badge = PanelBadge(todaySummary: "今天的事都做完了", dueReminders: 2)
        #expect(badge.needsAttention)
        #expect(badge.hint == "今天的事都做完了，有 2 条提醒到时间了\n点一下展开，拖动可以移动")
    }

    @Test func theWeatherOutsideIsNamedInTheHint() {
        let badge = PanelBadge(todaySummary: "今天还有 3 件事", dueReminders: 1, weather: "杭州 小雨 19°")
        #expect(badge.hint == "今天还有 3 件事，有 1 条提醒到时间了\n杭州 小雨 19°\n点一下展开，拖动可以移动")
    }

    @Test func theSmallBadgeKeepsTheTopRightCornerAndStaysOnScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1055)
        let badge = CGSize(width: PanelBadge.size, height: PanelBadge.size)
        let atCorner = PanelPlacement.frame(size: badge, anchor: CGPoint(x: 900, y: 700), screens: [screen], margin: 10)
        #expect(atCorner.maxX == 900)
        #expect(atCorner.maxY == 700)

        let nearEdge = PanelPlacement.frame(size: badge, anchor: CGPoint(x: 20, y: 30), screens: [screen], margin: 10)
        #expect(screen.contains(nearEdge))
    }
}
