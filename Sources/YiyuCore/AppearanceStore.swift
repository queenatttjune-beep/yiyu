import Foundation

/// Reads and writes `AppearanceSettings` as `appearance.json` next to the data file.
public struct AppearanceStore: Sendable {
    public struct LoadResult: Equatable, Sendable {
        public let settings: AppearanceSettings
        public let outcome: DataStore.LoadOutcome
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var fileURL: URL { directory.appendingPathComponent("appearance.json") }

    /// An unreadable file is moved aside rather than overwritten, so hand-made skins can be recovered.
    public func load() throws -> LoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return LoadResult(settings: .default, outcome: .fresh)
        }
        do {
            let raw = try Data(contentsOf: fileURL)
            let settings = try JSONDecoder().decode(AppearanceSettings.self, from: raw)
            return LoadResult(settings: settings, outcome: .loaded)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = directory.appendingPathComponent("appearance.unreadable-\(stamp).json")
            try fileManager.moveItem(at: fileURL, to: aside)
            return LoadResult(settings: .default, outcome: .recovered(backupURL: aside))
        }
    }

    public func save(_ settings: AppearanceSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(settings).write(to: fileURL, options: .atomic)
    }
}
