import Foundation
import Testing
@testable import YiyuCore

struct MemoBookTests {
    let now = Fixtures.now

    private func memo(_ text: String, pinned: Bool = false, updatedAt: Date = Fixtures.now) -> Memo {
        Memo(text: text, isPinned: pinned, createdAt: Fixtures.date(2026, 10, 1), updatedAt: updatedAt)
    }

    @Test func titleAndPreviewComeFromFirstLines() {
        let note = memo("\n  快递单号  \n\n SF1234567 \n其他")
        #expect(note.title == "快递单号")
        #expect(note.preview == "SF1234567")
        #expect(memo("   ").title == "新备忘")
        #expect(memo("只有一行").preview == "")
    }

    @Test func creatingAddsEmptyMemoAtNow() {
        let id = UUID()
        let result = MemoBook.creating(id: id, in: [], now: now)
        #expect(result.count == 1)
        #expect(result[0].id == id)
        #expect(result[0].text == "")
        #expect(result[0].createdAt == now)
    }

    @Test func updatingChangesTextAndTimestamp() {
        let original = [memo("旧", updatedAt: Fixtures.date(2026, 10, 2))]
        let updated = MemoBook.updating(original[0].id, text: "新", in: original, now: now)
        #expect(updated[0].text == "新")
        #expect(updated[0].updatedAt == now)
        #expect(original[0].text == "旧")
    }

    @Test func sortedPutsPinnedFirstThenRecent() {
        let old = memo("old", updatedAt: Fixtures.date(2026, 10, 2))
        let recent = memo("recent", updatedAt: Fixtures.date(2026, 10, 20))
        let pinned = memo("pinned", pinned: true, updatedAt: Fixtures.date(2026, 9, 1))
        #expect(MemoBook.sorted([old, recent, pinned]).map(\.title) == ["pinned", "recent", "old"])
    }

    @Test func pinToggleRemoveAndSearch() {
        let wifi = memo("家里 WiFi\n密码 abc")
        let book = memo("书单")
        let pinned = MemoBook.togglingPin(wifi.id, in: [wifi, book])
        #expect(pinned[0].isPinned)
        #expect(MemoBook.removing(wifi.id, from: [wifi, book]) == [book])
        #expect(MemoBook.searching([wifi, book], query: "wifi").map(\.id) == [wifi.id])
        #expect(MemoBook.searching([wifi, book], query: "  ").count == 2)
    }

    @Test func pruningDropsBlankMemosExceptTheOneBeingEdited() {
        let blank = memo("  ")
        let editing = memo("")
        let kept = memo("有内容")
        let pruned = MemoBook.pruningEmpty([blank, editing, kept], keeping: editing.id)
        #expect(pruned.map(\.id) == [editing.id, kept.id])
    }
}

struct DiaryBookTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.now
    let today = Fixtures.today

    @Test func writingCreatesThenUpdatesEntry() {
        let created = DiaryBook.writing("今天去爬山了。", for: today, in: [], now: now)
        #expect(DiaryBook.text(for: today, in: created) == "今天去爬山了。")

        let later = Fixtures.date(2026, 10, 25, 22)
        let updated = DiaryBook.writing("今天去爬山了，很开心。", for: today, in: created, now: later)
        #expect(updated.count == 1)
        #expect(updated[0].updatedAt == later)
    }

    @Test func blankTextRemovesEntry() {
        let created = DiaryBook.writing("内容", for: today, in: [], now: now)
        #expect(DiaryBook.writing(" \n ", for: today, in: created, now: now).isEmpty)
    }

    @Test func missingDayReadsAsEmpty() {
        #expect(DiaryBook.text(for: today, in: []) == "")
    }

    @Test func writtenDaysAndCharacterCount() {
        let yesterday = today.adding(days: -1, calendar: calendar)
        let entries = DiaryBook.writing("a", for: yesterday, in: DiaryBook.writing("b", for: today, in: [], now: now), now: now)
        #expect(DiaryBook.writtenDays(in: entries) == [today, yesterday])
        #expect(DiaryBook.characterCount("今天 很好\n。 ") == 5)
    }
}
