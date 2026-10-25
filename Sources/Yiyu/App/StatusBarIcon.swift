import AppKit
import YiyuCore

/// A seasonal flower in the foreground, with one weather sign in the open upper left.
@MainActor
enum StatusBarIcon {
    static func image(for motif: WeatherScene.Motif, flower: GardenFlower = .plum) -> NSImage {
        let weather: GardenWeather = switch motif {
        case .blossom: .quiet
        case .sun, .moon: .clear
        case .rain: .rain
        case .snow: .snow
        case .mist: .mist
        }
        return MoonGateMark.menuBarImage(scene: GardenScene(flower: flower, weather: weather, isNight: motif == .moon))
    }
}
