import SwiftUI
import YiyuCore

/// A small copy of the panel in the selected skin, so changes show even when the real panel is hidden.
struct SkinPreview: View {
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("预览")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            panel
            Text("屏幕角落的面板也会一起变。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            InputField(text: .constant(""), placeholder: "写下今天要做的事，回车添加")
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            row("整理这周的照片")
            row("回复房东的消息", lateLabel: "昨天")
            row("买打印纸", isDone: true)
            SectionLabel(text: "日记")
            Text("上午去公园走了一圈，银杏开始黄了，风一吹落了一地。")
                .font(Theme.diary(14.5))
                .foregroundStyle(Theme.ink)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.rowInset)
                .padding(.bottom, 16)
        }
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.goldFaint, lineWidth: 0.5)
        )
        .environment(\.colorScheme, Theme.colorScheme)
        .tint(Theme.gold)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("面板预览")
    }

    private var header: some View {
        let today = DayKey(Date(), calendar: calendar)
        return HStack(spacing: 10) {
            Text("\(today.day)")
                .font(Theme.serif(34, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Labels.chineseMonth(today.month))  \(Labels(calendar: calendar).weekday(today))")
                    .font(Theme.serif(13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(Labels.todaySummary(remaining: 2, total: 3))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var tabs: some View {
        HStack(spacing: 14) {
            ForEach(PanelTab.allCases) { tab in
                let isCurrent = tab == .today
                VStack(spacing: 4) {
                    Text(tab.title)
                        .font(Theme.text(12, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Theme.gold : Theme.inkMuted)
                    Capsule()
                        .fill(isCurrent ? Theme.gold : Color.clear)
                        .frame(width: 12, height: 2)
                }
            }
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.bottom, 6)
    }

    private func row(_ title: String, isDone: Bool = false, lateLabel: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CheckMark(isOn: isDone) {}
                .padding(.top, 1)
            Text(title)
                .font(Theme.body)
                .foregroundStyle(isDone ? Theme.inkMuted : Theme.ink)
                .strikethrough(isDone, color: Theme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let lateLabel {
                Text(lateLabel)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.seal)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.vertical, 6)
    }
}
