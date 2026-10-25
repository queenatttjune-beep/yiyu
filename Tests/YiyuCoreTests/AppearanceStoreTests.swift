import Foundation
import Testing
@testable import YiyuCore

struct AppearanceStoreTests {
    private func makeStore() -> AppearanceStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("yiyu-appearance-\(UUID().uuidString)", isDirectory: true)
        return AppearanceStore(directory: directory)
    }

    private func write(_ text: String, to store: AppearanceStore) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: store.fileURL)
    }

    @Test func missingFileLoadsTheDefaults() throws {
        let result = try makeStore().load()
        #expect(result.settings == .default)
        #expect(result.outcome == .fresh)
    }

    @Test func savesAndLoadsCustomSkins() throws {
        let store = makeStore()
        let edited = SkinBook.editingSelected(in: .default, newID: "mine-1") { skin in
            skin.with(palette: skin.palette.with(.paper, .white), fonts: skin.fonts.with(.diary, "Kaiti SC").with(scale: 1.08))
        }
        try store.save(edited)

        let result = try store.load()
        #expect(result.settings == edited)
        #expect(result.outcome == .loaded)
        let json = try String(contentsOf: store.fileURL, encoding: .utf8)
        #expect(json.contains(##""paper" : "#FFFFFF""##))
    }

    @Test func unreadableFileIsSetAsideAndDefaultsAreUsed() throws {
        let store = makeStore()
        try write("{ not json", to: store)

        let result = try store.load()

        #expect(result.settings == .default)
        guard case .recovered(let backupURL) = result.outcome else {
            Issue.record("Expected recovered outcome, got \(result.outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    @Test func partialSkinsAreCompletedFromTheDefault() throws {
        let store = makeStore()
        try write(#"""
        {"selectedSkinID": "x", "customSkins": [{"id": "x", "name": "白", "palette": {"paper": "#FFFFFF"}}]}
        """#, to: store)

        let skin = SkinBook.selected(try store.load().settings)

        #expect(skin.id == "x")
        #expect(skin.palette.paper == .white)
        #expect(skin.palette.ink == Skin.default.palette.ink)
        #expect(skin.fonts == Skin.default.fonts)
    }
}
