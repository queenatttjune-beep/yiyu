import SwiftUI
import YiyuCore

struct RemindersPage: View {
    let model: AppModel
    let ui: PanelState

    @State private var draft = ""
    @State private var manualDate = RemindersPage.nextWholeHour()
    @State private var manualRule: RepeatRule = .none
    @State private var showsDone = false

    var body: some View {
        VStack(spacing: 0) {
            InputField(
                text: $draft,
                placeholder: "什么时候，提醒你做什么？",
                leadingIcon: "bell",
                focusRequest: ui.focusRequest,
                onSubmit: add
            )
            .padding(.horizontal, 10)

            composerHint
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    list
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear { manualDate = Self.nextWholeHour() }
        .onChange(of: draft.isEmpty) { _, isEmpty in
            if !isEmpty, manualDate <= Date() {
                manualDate = Self.nextWholeHour()
            }
        }
    }

    @ViewBuilder private var composerHint: some View {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("例如：明天下午3点 交作业、每天早上8点 吃药")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let parsed = model.parser.parse(trimmed, now: model.now)
            if parsed.isInThePast(now: Date()) {
                Text("这个时间已经过了。改成以后的时间，或者回车照样记下。")
                    .font(Theme.caption.weight(.medium))
                    .foregroundStyle(Theme.seal)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let fireAt = parsed.fireAt {
                Text(preview(title: parsed.title, fireAt: fireAt, rule: parsed.repeatRule))
                    .font(Theme.caption.weight(.medium))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(2)
            } else {
                HStack(spacing: 6) {
                    Text("没认出时间，用")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkMuted)
                    DatePicker("", selection: $manualDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .controlSize(.small)
                        .fixedSize()
                    RepeatMenu(rule: $manualRule)
                }
            }
        }
    }

    @ViewBuilder private var list: some View {
        let due = model.dueReminders
        let upcoming = model.upcomingReminders
        if due.isEmpty && upcoming.isEmpty {
            EmptyHint(
                title: "没有提醒。",
                detail: "在上面用一句话写下时间和事情，到点会弹出系统通知，这里也会标红。"
            )
        }
        if !due.isEmpty {
            SectionLabel(text: "已到时间")
            ForEach(due) { ReminderRow(reminder: $0, model: model) }
            if !upcoming.isEmpty {
                SectionLabel(text: "接下来")
            }
        }
        ForEach(upcoming) { ReminderRow(reminder: $0, model: model) }

        let done = model.data.reminders.filter(\.isDone)
        if !done.isEmpty {
            CompletedFooter(count: done.count, unit: "条", isExpanded: $showsDone, onClear: model.clearDoneReminders)
            if showsDone {
                ForEach(done) { ReminderRow(reminder: $0, model: model) }
            }
        }
    }

    private func preview(title: String, fireAt: Date, rule: RepeatRule) -> String {
        let time = model.labels.reminderTime(fireAt, now: model.now)
        let repeatText = rule == .none ? "" : "，\(rule.label)"
        return "\(time)\(repeatText) 提醒「\(title)」，回车添加"
    }

    private func add(_ text: String) {
        let parsed = model.parser.parse(text, now: Date())
        if let fireAt = parsed.fireAt {
            model.addReminder(parsed.title, at: fireAt, repeatRule: parsed.repeatRule)
        } else {
            model.addReminder(parsed.title, at: manualDate, repeatRule: manualRule)
        }
        manualRule = .none
        manualDate = Self.nextWholeHour()
    }

    private static func nextWholeHour(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? date
    }
}

private struct RepeatMenu: View {
    @Binding var rule: RepeatRule

    var body: some View {
        Menu {
            ForEach(RepeatRule.allCases, id: \.self) { option in
                Button(option.label) { rule = option }
            }
        } label: {
            Text(rule.label)
                .font(Theme.caption)
                .foregroundStyle(Theme.gold)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
    }
}
