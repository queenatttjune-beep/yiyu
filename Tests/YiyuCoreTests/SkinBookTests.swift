import Foundation
import Testing
@testable import YiyuCore

struct SkinBookTests {
    private let accent = ThemeColor(rgb: 0x336699)

    private func recolor(_ skin: Skin) -> Skin {
        skin.with(palette: skin.palette.with(.accent, accent))
    }

    private func custom(_ id: String, _ name: String) -> Skin {
        Skin(id: id, name: name, palette: Skin.default.palette, fonts: Skin.default.fonts)
    }

    @Test func freshSettingsSelectTheDefaultSkin() {
        let settings = AppearanceSettings.default
        #expect(SkinBook.selected(settings) == .default)
        #expect(SkinBook.allSkins(settings) == Skin.builtIns)
    }

    @Test func unknownSelectionFallsBackToTheDefault() {
        let settings = AppearanceSettings(selectedSkinID: "gone")
        #expect(SkinBook.selected(settings) == .default)
    }

    @Test func selectingAKnownSkinOnly() {
        let settings = SkinBook.selecting("xuanzhi", in: .default)
        #expect(settings.selectedSkinID == "xuanzhi")
        #expect(SkinBook.selecting("nope", in: settings) == settings)
    }

    @Test func editingABuiltInSkinSavesAnEditedCopy() {
        let original = AppearanceSettings.default
        let edited = SkinBook.editingSelected(in: original, newID: "mine-1", recolor)

        #expect(edited.selectedSkinID == "mine-1")
        #expect(edited.customSkins.count == 1)
        let copy = edited.customSkins[0]
        #expect(copy.name == "我的磁青泥金")
        #expect(copy.palette.accent == accent)
        #expect(copy.fonts == Skin.default.fonts)
        #expect(Skin.builtIns[0].palette.accent.hex == "#C8A96A")
        #expect(original.customSkins.isEmpty)
    }

    @Test func editingTheCopyAgainChangesItInPlace() {
        let first = SkinBook.editingSelected(in: .default, newID: "mine-1", recolor)
        let second = SkinBook.editingSelected(in: first, newID: "mine-2") { skin in
            skin.with(fonts: skin.fonts.with(.body, "Kaiti SC"))
        }
        #expect(second.customSkins.map(\.id) == ["mine-1"])
        #expect(second.customSkins[0].palette.accent == accent)
        #expect(second.customSkins[0].fonts.body == "Kaiti SC")
    }

    @Test func anEditThatChangesNothingDoesNotMakeACopy() {
        let settings = SkinBook.editingSelected(in: .default, newID: "mine-1") { $0 }
        #expect(settings == .default)
    }

    @Test func copiesGetUniqueNames() {
        let once = SkinBook.editingSelected(in: .default, newID: "a", recolor)
        let back = SkinBook.selecting(Skin.default.id, in: once)
        let twice = SkinBook.editingSelected(in: back, newID: "b", recolor)
        #expect(twice.customSkins.map(\.name) == ["我的磁青泥金", "我的磁青泥金 2"])
    }

    @Test func duplicatingSelectsTheCopy() {
        let base = AppearanceSettings(selectedSkinID: "a", customSkins: [custom("a", "夜读")])
        let settings = SkinBook.duplicating("a", newID: "b", in: base)
        #expect(settings.customSkins.map(\.name) == ["夜读", "夜读 2"])
        #expect(settings.selectedSkinID == "b")
        #expect(SkinBook.duplicating("xuanzhi", newID: "c", in: .default).customSkins.map(\.name) == ["我的宣纸"])
        #expect(SkinBook.duplicating("nope", newID: "d", in: base) == base)
    }

    @Test func renamingTrimsAndIgnoresBlankOrBuiltIn() {
        let base = AppearanceSettings(selectedSkinID: "a", customSkins: [custom("a", "夜读")])
        #expect(SkinBook.renaming("a", to: "  晨读 ", in: base).customSkins[0].name == "晨读")
        #expect(SkinBook.renaming("a", to: "   ", in: base) == base)
        #expect(SkinBook.renaming(Skin.default.id, to: "改名", in: base) == base)
        let long = String(repeating: "长", count: 40)
        #expect(SkinBook.renaming("a", to: long, in: base).customSkins[0].name.count == SkinBook.maxNameLength)
    }

    @Test func removingTheSelectedCopyFallsBackToTheDefault() {
        let base = AppearanceSettings(selectedSkinID: "a", customSkins: [custom("a", "夜读"), custom("b", "晨读")])
        let settings = SkinBook.removing("a", from: base)
        #expect(settings.customSkins.map(\.id) == ["b"])
        #expect(settings.selectedSkinID == Skin.default.id)

        let other = SkinBook.removing("b", from: base)
        #expect(other.selectedSkinID == "a")
        #expect(SkinBook.removing(Skin.default.id, from: base) == base)
    }

    @Test func builtInIDsAreRecognised() {
        #expect(SkinBook.isBuiltIn("xuanzhi"))
        #expect(!SkinBook.isBuiltIn("mine-1"))
    }

    @Test func settingsDecodeMissingFieldsAsDefaults() throws {
        let settings = try JSONDecoder().decode(AppearanceSettings.self, from: Data("{}".utf8))
        #expect(settings == .default)
    }

    @Test func decodingDropsSkinsThatReuseAnID() throws {
        let json = #"""
        {"customSkins": [{"id": "ciqing", "name": "冒名"}, {"id": "a", "name": "甲"}, {"id": "a", "name": "乙"}]}
        """#
        let settings = try JSONDecoder().decode(AppearanceSettings.self, from: Data(json.utf8))
        #expect(settings.customSkins.map(\.name) == ["甲"])
    }
}
