import Foundation

public struct Todo: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    /// The day this is planned for; `nil` keeps it in the backlog.
    public var plannedDay: DayKey?
    public var completedAt: Date?
    public let createdAt: Date

    public var isDone: Bool { completedAt != nil }

    public init(
        id: UUID = UUID(),
        title: String,
        plannedDay: DayKey? = nil,
        completedAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.plannedDay = plannedDay
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}

public enum RepeatRule: String, Codable, CaseIterable, Sendable {
    case none
    case daily
    case weekdays
    case weekly

    public var label: String {
        switch self {
        case .none: "不重复"
        case .daily: "每天"
        case .weekdays: "工作日"
        case .weekly: "每周"
        }
    }
}

public struct Reminder: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var fireAt: Date
    public var repeatRule: RepeatRule
    public var isDone: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        fireAt: Date,
        repeatRule: RepeatRule,
        isDone: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.fireAt = fireAt
        self.repeatRule = repeatRule
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

public struct Memo: Codable, Identifiable, Equatable, Sendable {
    public static let untitled = "新备忘"

    public let id: UUID
    public var text: String
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), text: String, isPinned: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.text = text
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private var contentLines: [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public var title: String { contentLines.first ?? Memo.untitled }
    public var preview: String { contentLines.dropFirst().first ?? "" }
    public var isBlank: Bool { contentLines.isEmpty }
}

public struct DiaryEntry: Codable, Equatable, Sendable {
    public let day: DayKey
    public var text: String
    public var updatedAt: Date

    public init(day: DayKey, text: String, updatedAt: Date) {
        self.day = day
        self.text = text
        self.updatedAt = updatedAt
    }
}

public struct AppData: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let empty = AppData()

    public var version: Int
    public var todos: [Todo]
    public var reminders: [Reminder]
    public var memos: [Memo]
    public var diary: [DiaryEntry]

    public init(
        version: Int = AppData.currentVersion,
        todos: [Todo] = [],
        reminders: [Reminder] = [],
        memos: [Memo] = [],
        diary: [DiaryEntry] = []
    ) {
        self.version = version
        self.todos = todos
        self.reminders = reminders
        self.memos = memos
        self.diary = diary
    }

    private enum CodingKeys: String, CodingKey {
        case version, todos, reminders, memos, diary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? AppData.currentVersion
        todos = try container.decodeIfPresent([Todo].self, forKey: .todos) ?? []
        reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        memos = try container.decodeIfPresent([Memo].self, forKey: .memos) ?? []
        diary = try container.decodeIfPresent([DiaryEntry].self, forKey: .diary) ?? []
    }
}
