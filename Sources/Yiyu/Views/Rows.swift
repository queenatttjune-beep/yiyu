import SwiftUI
import YiyuCore

struct TodoRow: View {
    enum Context {
        case today
        case backlog
    }

    let todo: Todo
    let model: AppModel
    let context: Context

    @State private var isHovering = false
    @State private var isEditing = false

    private var isPlannedForToday: Bool {
        guard let planned = todo.plannedDay else { return false }
        return planned <= model.today
    }

    var body: some View {
        Group {
            if isEditing {
                TodoEditor(todo: todo, model: model) { isEditing = false }
            } else {
                row
                    .contextMenu { menu }
            }
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.vertical, 7)
        .background(isHovering ? Theme.field.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 10) {
            CheckMark(isOn: todo.isDone) { model.toggleTodo(todo.id) }
                .padding(.top, 1)
            title
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
    }

    private var title: some View {
        Text(todo.title)
            .font(Theme.body)
            .foregroundStyle(todo.isDone ? Theme.inkMuted : Theme.ink)
            .strikethrough(todo.isDone, color: Theme.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
            .onTapGesture(count: 2, perform: beginEdit)
            .help("双击编辑")
    }

    @ViewBuilder private var trailing: some View {
        HStack(spacing: 2) {
            if let label = dayLabel {
                Text(label.text)
                    .font(Theme.caption)
                    .foregroundStyle(label.isLate ? Theme.seal : Theme.inkMuted)
                    .padding(.top, 2)
            }
            if isHovering {
                IconButton(systemName: "pencil", help: "编辑待办", size: 11, action: beginEdit)
                    .accessibilityLabel("编辑待办")
                    .padding(.top, -3)
                IconButton(systemName: "trash", help: "删除", size: 11) { model.deleteTodo(todo.id) }
                    .padding(.top, -3)
            }
            if context == .backlog && !todo.isDone {
                IconButton(
                    systemName: isPlannedForToday ? "sun.max.fill" : "sun.max",
                    help: isPlannedForToday ? "移出今天" : "今天做",
                    tint: isPlannedForToday ? Theme.gold : Theme.inkFaint
                ) {
                    model.planTodo(todo.id, daysFromToday: isPlannedForToday ? nil : 0)
                }
                .padding(.top, -3)
            }
        }
    }

    private var dayLabel: (text: String, isLate: Bool)? {
        guard let planned = todo.plannedDay, !todo.isDone else { return nil }
        let today = model.today
        if planned < today {
            return (model.labels.relativeDay(planned, today: today), true)
        }
        if context == .backlog && planned > today {
            return (model.labels.relativeDay(planned, today: today), false)
        }
        return nil
    }

    @ViewBuilder private var menu: some View {
        Button("编辑", action: beginEdit)
        if !todo.isDone {
            if todo.plannedDay != model.today {
                Button("今天做") { model.planTodo(todo.id, daysFromToday: 0) }
            }
            Button("明天做") { model.planTodo(todo.id, daysFromToday: 1) }
            if todo.plannedDay != nil {
                Button("不排日期") { model.planTodo(todo.id, daysFromToday: nil) }
            }
        }
        Divider()
        Button("删除", role: .destructive) { model.deleteTodo(todo.id) }
    }

    private func beginEdit() {
        isEditing = true
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let model: AppModel

    @State private var isHovering = false
    @State private var isEditing = false

    private var isDue: Bool { !reminder.isDone && reminder.fireAt <= model.now }
    private var isRepeating: Bool { reminder.repeatRule != .none }

    var body: some View {
        Group {
            if isEditing {
                ReminderEditor(reminder: reminder, model: model) { isEditing = false }
            } else {
                row
                    .contextMenu { menu }
            }
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.vertical, 7)
        .background(isHovering ? Theme.field.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 10) {
            CheckMark(isOn: reminder.isDone, tint: isDue ? Theme.seal : Theme.gold) {
                model.toggleReminder(reminder.id)
            }
            .help(isRepeating ? "跳过这一次" : (reminder.isDone ? "恢复" : "完成"))
            .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(Theme.body)
                    .foregroundStyle(reminder.isDone ? Theme.inkMuted : Theme.ink)
                    .strikethrough(reminder.isDone, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(timeText)
                        .font(Theme.caption.monospacedDigit())
                        .foregroundStyle(isDue ? Theme.seal : Theme.inkMuted)
                    if reminder.repeatRule != .none {
                        Label(reminder.repeatRule.label, systemImage: "repeat")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkMuted)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { isEditing = true }
            .help("双击编辑")
            if isHovering {
                HStack(spacing: 0) {
                    IconButton(systemName: "pencil", help: "编辑提醒", size: 11) { isEditing = true }
                        .accessibilityLabel("编辑提醒")
                    if isDue {
                        IconButton(systemName: "clock.arrow.circlepath", help: "10 分钟后再提醒", size: 11) {
                            model.snoozeReminder(reminder.id, by: 10 * 60)
                        }
                    }
                    IconButton(systemName: "trash", help: "删除", size: 11) { model.deleteReminder(reminder.id) }
                }
                .padding(.top, -3)
            }
        }
    }

    @ViewBuilder private var menu: some View {
        Button("编辑") { isEditing = true }
        Divider()
        Button("10 分钟后再提醒") { model.snoozeReminder(reminder.id, by: 10 * 60) }
        Button("1 小时后再提醒") { model.snoozeReminder(reminder.id, by: 3600) }
        if isRepeating {
            Button("跳过这一次") { model.toggleReminder(reminder.id) }
        } else {
            Button("明天这个时候再提醒") { model.snoozeReminder(reminder.id, by: 24 * 3600) }
        }
        Divider()
        Button(isRepeating ? "删除（不再重复）" : "删除", role: .destructive) { model.deleteReminder(reminder.id) }
    }

    private var timeText: String {
        let time = model.labels.reminderTime(reminder.fireAt, now: model.now)
        return isDue ? "已到 \(time)" : time
    }
}
