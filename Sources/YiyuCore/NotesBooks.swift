import Foundation

/// Pure operations on memos. Every function returns a new array.
public enum MemoBook {
    public static func creating(id: UUID, in memos: [Memo], now: Date) -> [Memo] {
        memos + [Memo(id: id, text: "", isPinned: false, createdAt: now, updatedAt: now)]
    }

    public static func updating(_ id: UUID, text: String, in memos: [Memo], now: Date) -> [Memo] {
        memos.map { memo in
            guard memo.id == id, memo.text != text else { return memo }
            var copy = memo
            copy.text = text
            copy.updatedAt = now
            return copy
        }
    }

    public static func togglingPin(_ id: UUID, in memos: [Memo]) -> [Memo] {
        memos.map { memo in
            guard memo.id == id else { return memo }
            var copy = memo
            copy.isPinned.toggle()
            return copy
        }
    }

    public static func removing(_ id: UUID, from memos: [Memo]) -> [Memo] {
        memos.filter { $0.id != id }
    }

    /// Drops memos with no content, except the one currently open in the editor.
    public static func pruningEmpty(_ memos: [Memo], keeping id: UUID?) -> [Memo] {
        memos.filter { !$0.isBlank || $0.id == id }
    }

    public static func sorted(_ memos: [Memo]) -> [Memo] {
        memos.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public static func searching(_ memos: [Memo], query: String) -> [Memo] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return memos }
        return memos.filter { $0.text.localizedCaseInsensitiveContains(needle) }
    }
}

/// Pure operations on diary entries, one entry per day.
public enum DiaryBook {
    public static func text(for day: DayKey, in entries: [DiaryEntry]) -> String {
        entries.first { $0.day == day }?.text ?? ""
    }

    /// Writes the day's text; blank text removes the entry.
    public static func writing(_ text: String, for day: DayKey, in entries: [DiaryEntry], now: Date) -> [DiaryEntry] {
        let others = entries.filter { $0.day != day }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return others }
        if let existing = entries.first(where: { $0.day == day }), existing.text == text {
            return entries
        }
        return others + [DiaryEntry(day: day, text: text, updatedAt: now)]
    }

    public static func writtenDays(in entries: [DiaryEntry]) -> Set<DayKey> {
        Set(entries.map(\.day))
    }

    public static func characterCount(_ text: String) -> Int {
        text.filter { !$0.isWhitespace && !$0.isNewline }.count
    }
}
