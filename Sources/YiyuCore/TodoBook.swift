import Foundation

/// Pure operations on the to-do list. Every function returns a new array.
public enum TodoBook {
    public static func adding(
        _ title: String,
        plannedDay: DayKey?,
        to todos: [Todo],
        now: Date,
        id: UUID = UUID()
    ) -> [Todo] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return todos }
        return todos + [Todo(id: id, title: trimmed, plannedDay: plannedDay, createdAt: now)]
    }

    public static func toggling(_ id: UUID, in todos: [Todo], now: Date) -> [Todo] {
        updating(id, in: todos) { todo in
            var copy = todo
            copy.completedAt = todo.isDone ? nil : now
            return copy
        }
    }

    public static func planning(_ id: UUID, for day: DayKey?, in todos: [Todo]) -> [Todo] {
        updating(id, in: todos) { todo in
            var copy = todo
            copy.plannedDay = day
            return copy
        }
    }

    public static func renaming(_ id: UUID, to title: String, in todos: [Todo]) -> [Todo] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return todos }
        return updating(id, in: todos) { todo in
            var copy = todo
            copy.title = trimmed
            return copy
        }
    }

    public static func editing(_ id: UUID, title: String, plannedDay: DayKey?, in todos: [Todo]) -> [Todo] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return todos }
        return updating(id, in: todos) { todo in
            var copy = todo
            copy.title = trimmed
            copy.plannedDay = plannedDay
            return copy
        }
    }

    public static func removing(_ id: UUID, from todos: [Todo]) -> [Todo] {
        todos.filter { $0.id != id }
    }

    public static func clearingCompleted(from todos: [Todo]) -> [Todo] {
        todos.filter { !$0.isDone }
    }

    /// Open items planned for today or earlier (carried over), then items finished today.
    public static func todayList(_ todos: [Todo], today: DayKey, calendar: Calendar) -> [Todo] {
        let open = todos
            .filter { !$0.isDone && isPlanned($0, onOrBefore: today) }
            .sorted { $0.createdAt > $1.createdAt }
        let finishedToday = todos
            .filter { todo in
                guard let completedAt = todo.completedAt, todo.plannedDay != nil else { return false }
                return DayKey(completedAt, calendar: calendar) == today
            }
            .sorted(by: completedRecentFirst)
        return open + finishedToday
    }

    public static func remainingToday(_ todos: [Todo], today: DayKey) -> Int {
        todos.filter { !$0.isDone && isPlanned($0, onOrBefore: today) }.count
    }

    public static func openList(_ todos: [Todo]) -> [Todo] {
        todos.filter { !$0.isDone }.sorted { $0.createdAt > $1.createdAt }
    }

    public static func completedList(_ todos: [Todo]) -> [Todo] {
        todos.filter(\.isDone).sorted(by: completedRecentFirst)
    }

    private static func isPlanned(_ todo: Todo, onOrBefore day: DayKey) -> Bool {
        guard let planned = todo.plannedDay else { return false }
        return planned <= day
    }

    private static func completedRecentFirst(_ lhs: Todo, _ rhs: Todo) -> Bool {
        (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
    }

    private static func updating(_ id: UUID, in todos: [Todo], transform: (Todo) -> Todo) -> [Todo] {
        todos.map { $0.id == id ? transform($0) : $0 }
    }
}
