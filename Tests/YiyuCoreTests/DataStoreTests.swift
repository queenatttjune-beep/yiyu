import Foundation
import Testing
@testable import YiyuCore

struct DataStoreTests {
    private func makeStore() throws -> DataStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("yiyu-tests-\(UUID().uuidString)", isDirectory: true)
        return DataStore(directory: directory)
    }

    private func sampleData() -> AppData {
        let now = Fixtures.date(2026, 10, 25, 10)
        return AppData(
            todos: [Todo(title: "交作业", plannedDay: Fixtures.today, createdAt: now)],
            reminders: [Reminder(title: "吃药", fireAt: now, repeatRule: .daily, isDone: false, createdAt: now)],
            memos: [Memo(text: "WiFi", isPinned: true, createdAt: now, updatedAt: now)],
            diary: [DiaryEntry(day: Fixtures.today, text: "晴", updatedAt: now)],
            customStyles: [WritingStyle.custom(name: "第三人称", instruction: "改成第三人称", id: "c1")]
        )
    }

    @Test func missingFileLoadsFreshEmptyData() throws {
        let store = try makeStore()
        let result = try store.load()
        #expect(result.data == .empty)
        #expect(result.outcome == .fresh)
    }

    @Test func savesAndLoadsRoundTrip() throws {
        let store = try makeStore()
        let data = sampleData()
        try store.save(data)
        let result = try store.load()
        #expect(result.data == data)
        #expect(result.outcome == .loaded)
    }

    @Test func corruptFileIsSetAsideAndStartsEmpty() throws {
        let store = try makeStore()
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.fileURL)

        let result = try store.load()

        #expect(result.data == .empty)
        guard case .recovered(let backupURL) = result.outcome else {
            Issue.record("Expected recovered outcome, got \(result.outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    @Test func missingKeysDecodeAsEmptyCollections() throws {
        let store = try makeStore()
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data("{\"version\": 1, \"memos\": []}".utf8).write(to: store.fileURL)

        let result = try store.load()
        #expect(result.data == .empty)
        #expect(result.outcome == .loaded)
    }

    @Test func dailyBackupIsWrittenOncePerDayAndPruned() throws {
        let store = try makeStore()
        try store.save(sampleData())

        let first = try store.backupIfNeeded(day: Fixtures.today)
        let second = try store.backupIfNeeded(day: Fixtures.today)
        #expect(first != nil)
        #expect(second == nil)

        for offset in 1...(DataStore.maxBackups + 3) {
            _ = try store.backupIfNeeded(day: Fixtures.today.adding(days: offset, calendar: Fixtures.calendar))
        }
        let backups = try FileManager.default.contentsOfDirectory(atPath: store.backupDirectory.path)
        #expect(backups.count == DataStore.maxBackups)
        #expect(!backups.contains("data-\(Fixtures.today).json"))
    }

    @Test func backupIsSkippedWhenNothingSavedYet() throws {
        let store = try makeStore()
        #expect(try store.backupIfNeeded(day: Fixtures.today) == nil)
    }

    @Test func onlyOneHolderCanLockTheDataFolder() throws {
        let store = try makeStore()
        let first = try store.lockForExclusiveUse()
        #expect(throws: DataStore.LockError.self) {
            _ = try store.lockForExclusiveUse()
        }
        first.release()
        let again = try store.lockForExclusiveUse()
        again.release()
    }
}
