import SwiftUI
import YiyuCore

struct TodayPage: View {
    let model: AppModel
    let ui: PanelState

    var body: some View {
        VStack(spacing: 0) {
            TodoComposer(model: model, ui: ui, forToday: true)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    OutfitCard()
                    if model.todayTodos.isEmpty {
                        EmptyHint(
                            title: "今天还没有安排。",
                            detail: "在上面写下第一件事，或者去「待办」里点太阳，把事情排进今天。"
                        )
                    }
                    ForEach(model.todayTodos) { todo in
                        TodoRow(todo: todo, model: model, context: .today)
                    }
                    let reminders = model.todaysReminders
                    if !reminders.isEmpty {
                        SectionLabel(text: "今天的提醒")
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder, model: model)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct BacklogPage: View {
    let model: AppModel
    let ui: PanelState

    @State private var showsCompleted = false

    var body: some View {
        VStack(spacing: 0) {
            TodoComposer(model: model, ui: ui, forToday: false)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let open = model.openTodos
                    let completed = model.completedTodos
                    if open.isEmpty && completed.isEmpty {
                        EmptyHint(
                            title: "没有待办。",
                            detail: "想到要做的事就写在上面。点右边的太阳，它就会出现在「今天」。"
                        )
                    }
                    ForEach(open) { todo in
                        TodoRow(todo: todo, model: model, context: .backlog)
                    }
                    if !completed.isEmpty {
                        CompletedFooter(
                            count: completed.count,
                            unit: "件",
                            isExpanded: $showsCompleted,
                            onClear: model.clearCompletedTodos
                        )
                        if showsCompleted {
                            ForEach(completed) { todo in
                                TodoRow(todo: todo, model: model, context: .backlog)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct TodoComposer: View {
    let model: AppModel
    let ui: PanelState
    let forToday: Bool

    @State private var draft = ""
    @State private var added: Todo?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            InputField(
                text: $draft,
                placeholder: forToday ? "写下要做的事，也可以说「明天写周报」" : "写下要做的事，例如「明天写周报」",
                focusRequest: ui.focusRequest,
                clearsOnSubmit: false,
                onSubmit: add
            )
            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parsed = model.todoParser.parse(draft, now: model.now)
                if let invalid = parsed.unresolvedDate {
                    hint("「\(invalid)」不是有效日期，请改一下。", color: Theme.seal)
                } else if parsed.title.isEmpty {
                    hint("再写下要做的事，例如「明天写周报」。", color: Theme.inkMuted)
                } else if parsed.plannedDay != nil || parsed.title != draft.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let day = parsed.plannedDay ?? (forToday ? model.today : nil)
                    hint("\(dayText(day)) · \(parsed.title)，回车添加", color: Theme.gold)
                }
            } else if let added, forToday, added.plannedDay != model.today {
                HStack(alignment: .firstTextBaseline) {
                    hint("已添加到\(dayText(added.plannedDay))：\(added.title)", color: Theme.inkMuted)
                    Button("查看") { ui.tab = .backlog }
                        .buttonStyle(.plain)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    private func hint(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
    }

    private func dayText(_ day: DayKey?) -> String {
        day.map { model.labels.relativeDay($0, today: model.today) } ?? "未安排日期"
    }

    private func add(_ input: String) {
        guard let todo = model.addTodo(input, forToday: forToday) else { return }
        added = todo
        draft = ""
    }
}
