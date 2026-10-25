import Foundation
import Testing
@testable import YiyuCore

struct FontCatalogTests {
    private let installed = ["Songti SC", "Kaiti SC", "Helvetica", ".SF NS", "Avenir", "PingFang SC"]

    @Test func recommendedKeepsSystemFirstAndOnlyInstalledFonts() {
        let families = FontCatalog.recommended(installed: Set(installed)).map(\.family)
        #expect(families == [ThemeFonts.system, "Songti SC", "Kaiti SC"])
    }

    @Test func othersListsRemainingVisibleFamiliesSorted() {
        #expect(FontCatalog.others(installed: installed) == ["Avenir", "Helvetica", "PingFang SC"])
    }

    @Test func labelsUseChineseNamesForKnownFonts() {
        #expect(FontCatalog.label(for: ThemeFonts.system) == "系统字体")
        #expect(FontCatalog.label(for: "Songti SC") == "宋体")
        #expect(FontCatalog.label(for: "Avenir") == "Avenir")
    }
}
