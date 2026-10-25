import SwiftUI
import YiyuCore

struct RootView: View {
    let model: AppModel
    @Bindable var ui: PanelState
    let actions: PanelActions

    var body: some View {
        Group {
            if ui.isCollapsed {
                CollapsedBadge(model: model, onExpand: actions.expand, onDragEnd: actions.panelDidMove)
            } else {
                ExpandedPanel(model: model, ui: ui, actions: actions)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .strokeBorder(Theme.goldFaint, lineWidth: 0.5)
                    )
            }
        }
        .environment(\.colorScheme, Theme.colorScheme)
        .tint(Theme.gold)
    }
}

private struct ExpandedPanel: View {
    let model: AppModel
    @Bindable var ui: PanelState
    let actions: PanelActions

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(model: model, actions: actions)
            TabBar(selection: $ui.tab, hasDueReminders: !model.dueReminders.isEmpty)
            if !model.firedReminders.isEmpty {
                FiredBanner(model: model)
            }
            if let message = model.saveError {
                Notice(text: message, color: Theme.seal)
            }
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder private var page: some View {
        switch ui.tab {
        case .today: TodayPage(model: model, ui: ui)
        case .backlog: BacklogPage(model: model, ui: ui)
        case .reminders: RemindersPage(model: model, ui: ui)
        case .memos: MemosPage(model: model, ui: ui)
        case .diary: DiaryPage(model: model, ui: ui)
        }
    }
}

private struct PanelHeader: View {
    let model: AppModel
    let actions: PanelActions

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(model.today.day)")
                    .font(Theme.serif(40, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Labels.chineseMonth(model.today.month))  \(model.labels.weekday(model.today))")
                        .font(Theme.serif(14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(model.todaySummary)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, Theme.rowInset)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .overlay(WindowDragArea(
                hint: "点一下收起，拖动来移动",
                onClick: actions.toggleCollapsed,
                onDragEnd: actions.panelDidMove
            ))

            HStack(spacing: 6) {
                HeaderWeather()
                Menu {
                    Button("隐藏面板", action: actions.hidePanel)
                    Button("放回右上角", action: actions.resetPosition)
                    Button("打开数据文件夹", action: actions.openDataFolder)
                    Button("外观与皮肤…") { AppearanceCommand.open() }
                    Button("天气设置…") { WeatherCommand.open() }
                    Divider()
                    Button("退出一隅", action: actions.quit)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.leading, 12)
            .padding(.trailing, Theme.rowInset)
            .padding(.top, 6)
        }
    }
}

private struct TabBar: View {
    @Binding var selection: PanelTab
    let hasDueReminders: Bool

    var body: some View {
        HStack(spacing: 20) {
            ForEach(PanelTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        HStack(spacing: 3) {
                            Text(tab.title)
                                .font(Theme.text(13, weight: selection == tab ? .semibold : .regular))
                                .foregroundStyle(selection == tab ? Theme.gold : Theme.inkMuted)
                            if tab == .reminders && hasDueReminders {
                                Circle().fill(Theme.seal).frame(width: 5, height: 5)
                            }
                        }
                        Capsule()
                            .fill(selection == tab ? Theme.gold : Color.clear)
                            .frame(width: 14, height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.shortcutHint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.bottom, 6)
    }
}

private struct FiredBanner: View {
    let model: AppModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.seal)
            Text("到时间了：" + model.firedReminders.map(\.title).joined(separator: "、"))
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("知道了") { model.acknowledgeFired() }
                .buttonStyle(.plain)
                .font(Theme.caption.weight(.semibold))
                .foregroundStyle(Theme.gold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.seal.opacity(0.16)))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
}
