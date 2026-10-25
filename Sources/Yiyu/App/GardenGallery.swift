#if DEBUG
import SwiftUI
import YiyuCore

/// Uses the production views and menu-bar artwork, with labelled synthetic conditions.
struct GardenGallery: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
    private let conditions: [(String, GardenScene)] = [
        ("晴日", .init(flower: .lotus, weather: .clear)),
        ("阴云", .init(flower: .lotus, weather: .cloudy)),
        ("雨中", .init(flower: .lotus, weather: .rain)),
        ("雪中", .init(flower: .lotus, weather: .snow)),
        ("雨雪", .init(flower: .lotus, weather: .sleet)),
        ("有风", .init(flower: .lotus, isWindy: true)),
        ("月下", .init(flower: .lotus, isNight: true)),
        ("薄雾", .init(flower: .lotus, weather: .mist)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("一门四时").font(Theme.serif(26, weight: .medium)).foregroundStyle(Theme.gold)
                Spacer()
                Text(Theme.skin.name).font(Theme.text(13)).foregroundStyle(Theme.inkMuted)
            }
            Text("时节换花，天气添景。每格展示放大图、52pt 小圆标和 18pt 菜单栏花形。")
                .font(Theme.text(12)).foregroundStyle(Theme.inkMuted)
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(GardenFlower.allCases, id: \.self) { flower in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            MoonGateMark(scene: .init(flower: flower)).frame(width: 88, height: 88)
                            badge(.init(flower: flower))
                            Image(nsImage: MoonGateMark.menuBarImage(flower: flower))
                                .renderingMode(.template).foregroundStyle(Theme.ink)
                                .frame(width: 18, height: 18)
                        }
                        Text(flower.name).font(Theme.serif(17)).foregroundStyle(Theme.ink)
                        Text(flower.months).font(Theme.text(11)).foregroundStyle(Theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Rectangle().fill(Theme.goldFaint).frame(height: 0.5)
            HStack {
                ForEach(conditions, id: \.0) { condition in
                    VStack(spacing: 10) {
                        badge(condition.1)
                        Text(condition.0).font(Theme.text(12)).foregroundStyle(Theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("测试预览 · 天气为模拟条件；月令为北半球意象，不代表当地实际花期。")
                .font(Theme.text(11)).foregroundStyle(Theme.inkMuted)
        }
        .padding(26)
        .frame(width: 860)
        .background(Theme.paper)
        .environment(\.colorScheme, Theme.colorScheme)
    }

    private func badge(_ scene: GardenScene) -> some View {
        let atmosphere: WeatherScene = switch scene.weather {
        case .quiet, .cloudy: .calm
        case .clear: .init(sky: scene.isNight ? .moon(.strong) : .sun(.strong))
        case .rain: .init(rain: .faint, mist: .faint)
        case .snow: .init(snow: .medium)
        case .sleet: .init(rain: .faint, snow: .faint)
        case .mist: .init(mist: .medium)
        }
        return Circle().fill(Theme.paper)
            .overlay(Circle().strokeBorder(Theme.goldFaint, lineWidth: 0.8))
            .overlay(GateSky(scene: atmosphere).padding(2))
            .overlay(MoonGateMark(scene: scene, drawsAtmosphere: atmosphere.isCalm).padding(2))
            .frame(width: 52, height: 52)
    }
}
#endif
