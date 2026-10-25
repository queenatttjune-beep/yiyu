import SwiftUI
import YiyuCore

struct TodoEditor: View {
    let todo: Todo
    let model: AppModel
    let onClose: () -> Void

    @State private var title: String
    @State private var hasDate: Bool
    @State private var date: Date

    init(todo: Todo, model: AppModel, onClose: @escaping () -> Void) {
        self.todo = todo
        self.model = model
        self.onClose = onClose
        _title = State(initialValue: todo.title)
        _hasDate = State(initialValue: todo.plannedDay != nil)
        _date = State(initialValue: (todo.plannedDay ?? model.today).startOfDay(in: model.calendar))
    }

    var body: some View {
        ItemEditor(title: $title, onSave: save, onCancel: onClose) {
            Toggle("安排日期", isOn: $hasDate)
                .toggleStyle(.checkbox)
            if hasDate {
                DatePicker("计划日期", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.field)
            }
        }
        .environment(\.calendar, model.calendar)
        .environment(\.timeZone, model.calendar.timeZone)
    }

    private func save() {
        let day = hasDate ? DayKey(date, calendar: model.calendar) : nil
        onClose()
        model.updateTodo(todo.id, title: title, plannedDay: day)
    }
}

struct ReminderEditor: View {
    let reminder: Reminder
    let model: AppModel
    let onClose: () -> Void

    @State private var title: String
    @State private var date: Date
    @State private var rule: RepeatRule

    init(reminder: Reminder, model: AppModel, onClose: @escaping () -> Void) {
        self.reminder = reminder
        self.model = model
        self.onClose = onClose
        _title = State(initialValue: reminder.title)
        _date = State(initialValue: reminder.fireAt)
        _rule = State(initialValue: reminder.repeatRule)
    }

    var body: some View {
        ItemEditor(title: $title, onSave: save, onCancel: onClose) {
            DatePicker("提醒时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.field)
            Picker("重复", selection: $rule) {
                ForEach(RepeatRule.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            if rule != .none, let next = ReminderBook.nextFire(
                after: model.now, from: date, rule: rule, calendar: model.calendar
            ) {
                Text("下次：\(model.labels.reminderTime(next, now: model.now))")
                    .foregroundStyle(Theme.inkMuted)
            } else if date <= model.now {
                Text("这个时间已经过了，保存后会标为已到时间。")
                    .foregroundStyle(Theme.seal)
            }
        }
        .environment(\.calendar, model.calendar)
        .environment(\.timeZone, model.calendar.timeZone)
    }

    private func save() {
        onClose()
        model.updateReminder(reminder.id, title: title, at: date, repeatRule: rule)
    }
}

/// Edits stay in local drafts until Save or Return; leaving the row never commits them.
private struct ItemEditor<Fields: View>: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let fields: Fields

    @FocusState private var isFocused: Bool

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("内容", text: $title)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.field))
                .focused($isFocused)
                .onSubmit { if isValid { onSave() } }
            fields
                .controlSize(.small)
            HStack(spacing: 12) {
                Spacer()
                Button("取消", action: onCancel)
                    .foregroundStyle(Theme.inkMuted)
                Button("保存", action: onSave)
                    .foregroundStyle(Theme.gold)
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.4)
            }
            .buttonStyle(.plain)
        }
        .font(Theme.caption)
        .foregroundStyle(Theme.ink)
        .onAppear { isFocused = true }
        .onExitCommand(perform: onCancel)
    }
}
