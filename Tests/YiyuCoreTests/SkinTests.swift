import Foundation
import Testing
@testable import YiyuCore

struct SkinTests {
    private func builtIn(_ id: String) throws -> Skin {
        try #require(Skin.builtIns.first { $0.id == id })
    }

    @Test func defaultSkinIsTheOriginalIndigoAndGold() {
        let skin = Skin.default
        #expect(skin.name == "磁青泥金")
        #expect(skin.palette.paper.hex == "#1E2B4D")
        #expect(skin.palette.accent.hex == "#C8A96A")
        #expect(skin.palette.alert.hex == "#D0644C")
        #expect(skin.fonts.display == "Songti SC")
        #expect(skin.fonts.body == ThemeFonts.system)
        #expect(skin.fonts.scale == 1)
    }

    @Test func builtInSkinsHaveUniqueIDsAndNames() {
        let ids = Skin.builtIns.map(\.id)
        let names = Skin.builtIns.map(\.name)
        #expect(Set(ids).count == ids.count)
        #expect(Set(names).count == names.count)
        #expect(Skin.builtIns.count >= 6)
    }

    @Test func everyBuiltInSkinIsReadable() {
        for skin in Skin.builtIns {
            #expect(skin.palette.hardToReadRoles.isEmpty, "\(skin.name): \(skin.palette.hardToReadRoles)")
        }
    }

    @Test func builtInsOfferBothDarkAndLightPaper() {
        #expect(Skin.builtIns.contains { $0.palette.isDark })
        #expect(Skin.builtIns.contains { !$0.palette.isDark })
    }

    @Test func darknessFollowsThePaper() throws {
        #expect(Skin.default.palette.isDark)
        #expect(try !builtIn("xuanzhi").palette.isDark)
        let white = Skin.default.palette.with(.paper, .white)
        #expect(!white.isDark)
    }

    @Test func textTooCloseToThePaperIsFlagged() {
        let palette = Skin.default.palette
            .with(.ink, Skin.default.palette.paper)
            .with(.alert, ThemeColor(rgb: 0x2A3759))
        #expect(palette.hardToReadRoles == [.ink, .alert])
    }

    @Test func paletteWithChangesOneRoleOnly() {
        let original = Skin.default.palette
        let changed = original.with(.accent, ThemeColor(rgb: 0x123456))
        #expect(changed[.accent].rgb == 0x123456)
        #expect(original[.accent].hex == "#C8A96A")
        for role in ColorRole.allCases where role != .accent {
            #expect(changed[role] == original[role])
        }
    }

    @Test func fontsWithChangesOneRoleAndClampsScale() {
        let fonts = Skin.default.fonts.with(.diary, "Kaiti SC")
        #expect(fonts[.diary] == "Kaiti SC")
        #expect(fonts[.display] == "Songti SC")
        #expect(fonts.with(scale: 9).scale == ThemeFonts.scaleRange.upperBound)
        #expect(fonts.with(scale: 0.1).scale == ThemeFonts.scaleRange.lowerBound)
    }

    @Test func everyOptionHasItsOwnLabel() {
        let colorLabels = ColorRole.allCases.map(\.label)
        let fontLabels = FontRole.allCases.map(\.label)
        let sizeLabels = TextSize.allCases.map(\.label)
        for labels in [colorLabels, fontLabels, sizeLabels] {
            #expect(Set(labels).count == labels.count)
            #expect(!labels.contains(""))
        }
        #expect(!ColorRole.allCases.map(\.detail).contains(""))
        #expect(!FontRole.allCases.map(\.detail).contains(""))
    }

    @Test func textSizeMatchesNearestScale() {
        #expect(TextSize(nearest: 1) == .standard)
        #expect(TextSize(nearest: 1.15) == .extraLarge)
        #expect(TextSize(nearest: 0.5) == .small)
        #expect(TextSize.allCases.map(\.scale) == TextSize.allCases.map(\.scale).sorted())
    }

    @Test func paletteDecodingFillsMissingRolesFromTheDefault() throws {
        let json = ##"{"paper": "#FFFFFF", "ink": "#000000"}"##
        let palette = try JSONDecoder().decode(ThemePalette.self, from: Data(json.utf8))
        #expect(palette.paper == .white)
        #expect(palette.ink == .black)
        #expect(palette.accent == Skin.default.palette.accent)
    }

    @Test func fontsDecodingFillsMissingFieldsAndClampsScale() throws {
        let json = #"{"body": "Kaiti SC", "scale": 40}"#
        let fonts = try JSONDecoder().decode(ThemeFonts.self, from: Data(json.utf8))
        #expect(fonts.body == "Kaiti SC")
        #expect(fonts.display == Skin.default.fonts.display)
        #expect(fonts.scale == ThemeFonts.scaleRange.upperBound)
    }
}
