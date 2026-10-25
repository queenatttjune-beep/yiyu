import Foundation

/// Reads and writes `AppData` as one JSON file, with a rolling daily backup.
public struct DataStore: Sendable {
    public static let maxBackups = 14

    public enum LoadOutcome: Equatable, Sendable {
        /// No data file yet: first launch.
        case fresh
        case loaded
        /// The data file could not be read; it was moved aside to `backupURL`.
        case recovered(backupURL: URL)
    }

    public struct LoadResult: Equatable, Sendable {
        public let data: AppData
        public let outcome: LoadOutcome
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public enum LockError: Error, Equatable {
        /// Another running copy of the app is using this data folder.
        case alreadyInUse
        case cannotOpen(errno: Int32)
    }

    /// Held for the app's lifetime so two copies never save over each other.
    public final class FolderLock {
        private var descriptor: Int32?

        fileprivate init(descriptor: Int32) {
            self.descriptor = descriptor
        }

        public func release() {
            guard let descriptor else { return }
            flock(descriptor, LOCK_UN)
            close(descriptor)
            self.descriptor = nil
        }

        deinit {
            release()
        }
    }

    public func lockForExclusiveUse() throws -> FolderLock {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent(".lock").path
        let descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else {
            throw LockError.cannotOpen(errno: errno)
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw LockError.alreadyInUse
        }
        return FolderLock(descriptor: descriptor)
    }

    public static func defaultDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return support.appendingPathComponent("Yiyu", isDirectory: true)
    }

    public var fileURL: URL { directory.appendingPathComponent("data.json") }
    public var backupDirectory: URL { directory.appendingPathComponent("backups", isDirectory: true) }

    public func load() throws -> LoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return LoadResult(data: .empty, outcome: .fresh)
        }
        do {
            let raw = try Data(contentsOf: fileURL)
            let data = try Self.decoder().decode(AppData.self, from: raw)
            return LoadResult(data: data, outcome: .loaded)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = directory.appendingPathComponent("data.unreadable-\(stamp).json")
            try fileManager.moveItem(at: fileURL, to: aside)
            return LoadResult(data: .empty, outcome: .recovered(backupURL: aside))
        }
    }

    public func save(_ data: AppData) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = try Self.encoder().encode(data)
        try encoded.write(to: fileURL, options: .atomic)
    }

    /// Copies the current data file into `backups/` once per day and keeps the newest `maxBackups`.
    /// Returns the new backup's URL, or `nil` when there was nothing to do.
    @discardableResult
    public func backupIfNeeded(day: DayKey) throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let target = backupDirectory.appendingPathComponent("data-\(day).json")
        guard !fileManager.fileExists(atPath: target.path) else { return nil }

        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try fileManager.copyItem(at: fileURL, to: target)
        try pruneBackups()
        return target
    }

    private func pruneBackups() throws {
        let fileManager = FileManager.default
        let names = try fileManager.contentsOfDirectory(atPath: backupDirectory.path)
            .filter { $0.hasPrefix("data-") && $0.hasSuffix(".json") }
            .sorted()
        for name in names.dropLast(Self.maxBackups) {
            try fileManager.removeItem(at: backupDirectory.appendingPathComponent(name))
        }
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
