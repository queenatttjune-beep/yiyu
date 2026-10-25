import Foundation
import Testing
@testable import YiyuCore

struct ThemeColorTests {
    @Test func parsesSixDigitHexWithOrWithoutHash() {
        #expect(ThemeColor(hex: "#1E2B4D")?.rgb == 0x1E2B4D)
        #expect(ThemeColor(hex: "c8a96a")?.rgb == 0xC8A96A)
        #expect(ThemeColor(hex: "  #ffffff ")?.rgb == 0xFFFFFF)
    }

    @Test func rejectsMalformedHex() {
        for bad in ["", "#", "#12345", "#1234567", "#GGGGGG", "+12345", "#12 345", "１２３４５６"] {
            #expect(ThemeColor(hex: bad) == nil, "\(bad) should not parse")
        }
    }

    @Test func formatsAsUppercaseHashHex() {
        #expect(ThemeColor(rgb: 0x0A0b0c).hex == "#0A0B0C")
        #expect(ThemeColor(rgb: 0).hex == "#000000")
    }

    @Test func buildsFromComponentsRoundedAndClamped() {
        #expect(ThemeColor(red: 1, green: 0.5, blue: 0).rgb == 0xFF8000)
        #expect(ThemeColor(red: 1.4, green: -0.2, blue: 0.2).rgb == 0xFF0033)
        let color = ThemeColor(rgb: 0x1E2B4D)
        #expect(ThemeColor(red: color.red, green: color.green, blue: color.blue) == color)
    }

    @Test func luminanceAndContrastFollowWCAG() {
        #expect(ThemeColor.black.relativeLuminance == 0)
        #expect(abs(ThemeColor.white.relativeLuminance - 1) < 1e-9)
        #expect(abs(ThemeColor.white.contrastRatio(with: .black) - 21) < 0.001)
        let gray = ThemeColor(rgb: 0x777777)
        #expect(abs(gray.contrastRatio(with: .white) - 4.48) < 0.01)
        #expect(gray.contrastRatio(with: .white) == ThemeColor.white.contrastRatio(with: gray))
        #expect(gray.contrastRatio(with: gray) == 1)
    }

    @Test func encodesAsHexString() throws {
        let data = try JSONEncoder().encode(["paper": ThemeColor(rgb: 0x1E2B4D)])
        #expect(String(decoding: data, as: UTF8.self) == ##"{"paper":"#1E2B4D"}"##)
        let decoded = try JSONDecoder().decode([String: ThemeColor].self, from: Data(##"{"a":"#abcdef"}"##.utf8))
        #expect(decoded["a"]?.rgb == 0xABCDEF)
    }

    @Test func decodingInvalidHexThrows() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode([ThemeColor].self, from: Data(#"["blue"]"#.utf8))
        }
    }
}
