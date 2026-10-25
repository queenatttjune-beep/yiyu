import SwiftUI
import YiyuCore

struct TodayPage: View {
    let model: AppModel
    let ui: PanelState

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            InputField(
                text: $draft,
                placeholder: "写下今天要做的事，回车添加",
                focusRequest: ui.focusRequest
            ) { model.addTodo($0, forToday: true) }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)

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

    @State private var draft = ""
    @State private var showsCompleted = false

    var body: some View {
        VStack(spacing: 0) {
            InputField(
                text: $draft,
                placeholder: "写下要做的事，回车添加",
                focusRequest: ui.focusRequest
            ) { model.addTodo($0, forToday: false) }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)

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
