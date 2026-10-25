import CoreGraphics
import Testing
@testable import YiyuCore

struct PrecipitationFieldTests {
    private let panel = CGSize(width: 344, height: 600)

    @Test func theSameMomentAlwaysGivesTheSameDrops() {
        let style = PrecipitationField.Style.rain(.faint)
        #expect(PrecipitationField.drops(style, in: panel, at: 12.5) == PrecipitationField.drops(style, in: panel, at: 12.5))
    }

    @Test func dropCountFollowsTheArea() {
        let style = PrecipitationField.Style.rain(.medium)
        let expected = Int((Double(panel.width * panel.height) / 10_000 * style.density).rounded())
        #expect(PrecipitationField.drops(style, in: panel, at: 0).count == expected)
        #expect(PrecipitationField.drops(style, in: .zero, at: 0).isEmpty)
    }

    /// The moon gate is only 30 points across, yet it should still show a handful of drops.
    @Test func theMoonGateGetsAHandfulOfDrops() {
        let gate = CGSize(width: 30, height: 30)
        for strength in [WeatherScene.Strength.faint, .medium, .strong] {
            #expect((6...20).contains(PrecipitationField.drops(.gateRain(strength), in: gate, at: 0).count))
            #expect((5...14).contains(PrecipitationField.drops(.gateSnow(strength), in: gate, at: 0).count))
        }
    }

    @Test func rainFallsDownAndLeansWithTheWind() {
        let style = PrecipitationField.Style.rain(.medium)
        let before = PrecipitationField.drops(style, in: panel, at: 3)
        let after = PrecipitationField.drops(style, in: panel, at: 3.05)
        let fell = zip(before, after).filter { $1.head.y > $0.head.y }
        // Only the few drops that just wrapped back to the top may have moved up.
        #expect(fell.count >= before.count * 9 / 10)
        for drop in before {
            #expect(drop.tail.y < drop.head.y)
            #expect(drop.tail.x > drop.head.x)
        }
    }

    @Test(arguments: [0.0, 7.3, 86_400.0 * 3])
    func dropsStayAroundTheAreaHoweverLongItRains(time: Double) {
        for style in [PrecipitationField.Style.rain(.strong), .snow(.strong), .gateRain(.faint), .gateSnow(.medium)] {
            let longest = style.length.upperBound + style.width.upperBound
            for drop in PrecipitationField.drops(style, in: panel, at: time) {
                #expect(drop.head.y >= 0 && drop.head.y <= Double(panel.height) + longest)
                #expect(drop.tail.y <= Double(panel.height) + style.width.upperBound)
                #expect(drop.opacity >= style.opacity.lowerBound && drop.opacity <= style.opacity.upperBound)
            }
        }
    }

    /// Spread across the whole width, so rain leaning in from the left still reaches the left edge.
    @Test func dropsCoverTheWholeWidth() {
        let drops = PrecipitationField.drops(.rain(.strong), in: panel, at: 1)
        let onScreen = drops.filter { $0.head.x >= 0 && $0.head.x <= panel.width }
        #expect(onScreen.contains { $0.head.x < panel.width * 0.1 })
        #expect(onScreen.contains { $0.head.x > panel.width * 0.9 })
    }

    @Test func snowflakesAreRoundAndSway() {
        let style = PrecipitationField.Style.snow(.medium)
        let flakes = PrecipitationField.drops(style, in: panel, at: 4)
        #expect(flakes.allSatisfy { $0.head == $0.tail })
        #expect(flakes.allSatisfy { style.width.contains(Double($0.width)) })

        let hovering = PrecipitationField.Style(
            kind: .snow, density: 3, speed: 0...0, length: 0...0, width: 2...2, opacity: 1...1, slant: 0, sway: 5
        )
        let now = PrecipitationField.drops(hovering, in: panel, at: 0)
        let later = PrecipitationField.drops(hovering, in: panel, at: 1)
        #expect(zip(now, later).allSatisfy { $0.head.y == $1.head.y && abs($0.head.x - $1.head.x) <= 10 })
        #expect(zip(now, later).contains { $0.head.x != $1.head.x })
    }

    @Test func strongerWeatherIsDenserAndFaster() {
        let presets: [(WeatherScene.Strength) -> PrecipitationField.Style] = [
            PrecipitationField.Style.rain, PrecipitationField.Style.snow,
            PrecipitationField.Style.gateRain, PrecipitationField.Style.gateSnow,
        ]
        for make in presets {
            let faint = make(.faint), medium = make(.medium), strong = make(.strong)
            #expect(faint.density < medium.density && medium.density < strong.density)
            #expect(faint.speed.lowerBound < medium.speed.lowerBound && medium.speed.lowerBound < strong.speed.lowerBound)
        }
    }

    /// The drizzle the user asked for: fine lines drifting down slowly, not a downpour.
    @Test func drizzleIsFineAndSlow() {
        let drizzle = PrecipitationField.Style.rain(.faint)
        #expect(drizzle.width.upperBound <= 1)
        #expect(drizzle.speed.upperBound <= 150)
        #expect(PrecipitationField.Style.snow(.strong).speed.upperBound < drizzle.speed.lowerBound)
    }

    @Test func scatterIsSpreadOverTheUnitInterval() {
        let values = (0..<1000).map { Scatter.unit($0, salt: 7) }
        #expect(values.allSatisfy { $0 >= 0 && $0 < 1 })
        #expect(values.filter { $0 < 0.5 }.count > 400)
        #expect(values.filter { $0 >= 0.5 }.count > 400)
        #expect(Scatter.unit(3, salt: 1) != Scatter.unit(3, salt: 2))
    }
}
