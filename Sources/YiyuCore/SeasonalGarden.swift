import Foundation

/// Calendar-inspired garden imagery, rather than a prediction of local flowering dates.
public enum GardenFlower: String, CaseIterable, Sendable {
    case plum, magnolia, crabapple, gardenia, lotus, osmanthus, chrysanthemum, camellia

    public var name: String {
        switch self {
        case .plum: "梅花"
        case .magnolia: "玉兰"
        case .crabapple: "海棠"
        case .gardenia: "栀子"
        case .lotus: "荷花"
        case .osmanthus: "桂花"
        case .chrysanthemum: "菊花"
        case .camellia: "山茶"
        }
    }

    public var months: String {
        switch self {
        case .plum: "一月 · 二月"
        case .magnolia: "三月"
        case .crabapple: "四月"
        case .gardenia: "五月 · 六月"
        case .lotus: "七月 · 八月"
        case .osmanthus: "九月"
        case .chrysanthemum: "十月 · 十一月"
        case .camellia: "十二月"
        }
    }

    fileprivate static func forMonth(_ month: Int) -> Self {
        switch month {
        case 1, 2: .plum
        case 3: .magnolia
        case 4: .crabapple
        case 5, 6: .gardenia
        case 7, 8: .lotus
        case 9: .osmanthus
        case 10, 11: .chrysanthemum
        default: .camellia
        }
    }
}

public enum GardenWeather: String, CaseIterable, Sendable {
    /// No fresh, matching weather: leave only the seasonal flower and time-of-day lighting.
    case quiet, clear, cloudy, rain, snow, sleet, mist

    fileprivate init(code: String) {
        guard let number = Int(code) else { self = .quiet; return }
        switch number {
        case 100, 150: self = .clear
        case 101...104, 151...153: self = .cloudy
        case 404...406, 456: self = .sleet
        case 300...318, 350, 351, 399: self = .rain
        case 400...403, 407...410, 457, 499: self = .snow
        case 500...504, 507...515: self = .mist
        default: self = .quiet
        }
    }
}

/// One shared decision for the floating badge, its accessible description, and the menu bar.
public struct GardenScene: Equatable, Sendable {
    public let flower: GardenFlower
    public let weather: GardenWeather
    public let isNight: Bool
    public let isWindy: Bool

    public init(flower: GardenFlower, weather: GardenWeather = .quiet, isNight: Bool = false, isWindy: Bool = false) {
        self.flower = flower
        self.weather = weather
        self.isNight = isNight
        self.isWindy = isWindy
    }

    public static func resolve(
        at date: Date, city: WeatherCity?, snapshot: WeatherSnapshot?, calendar: Calendar = .autoupdatingCurrent
    ) -> Self {
        // Even when the Mac uses a lunar calendar, the art follows Gregorian months.
        var local = Calendar(identifier: .gregorian)
        local.timeZone = city?.calendar(basedOn: calendar).timeZone ?? calendar.timeZone
        var month = local.component(.month, from: date)
        if let city, city.latitude < 0 { month = (month + 5) % 12 + 1 }
        let flower = GardenFlower.forMonth(month)
        let hour = local.component(.hour, from: date)
        let matchingSnapshot = snapshot.flatMap {
            $0.cityID == city?.id && $0.fetchedAt <= date ? $0 : nil
        }
        let isNight = matchingSnapshot?.isNight(at: date) ?? (hour < 6 || hour >= 19)

        guard let conditions = WeatherScene.conditions(in: matchingSnapshot, at: date) else {
            return Self(flower: flower, isNight: isNight)
        }
        return Self(
            flower: flower, weather: GardenWeather(code: conditions.condition.code),
            isNight: isNight, isWindy: (conditions.windScale ?? 0) >= 4
        )
    }

    public var description: String {
        let atmosphere: String
        switch weather {
        case .quiet: atmosphere = isNight ? "月下" : "当季花景"
        case .clear: atmosphere = isNight ? "晴夜" : "晴日"
        case .cloudy: atmosphere = isNight ? "多云的夜晚" : "阴云"
        case .rain: atmosphere = isNight ? "夜雨" : "雨中"
        case .snow: atmosphere = isNight ? "夜雪" : "雪中"
        case .sleet: atmosphere = "雨雪中"
        case .mist: atmosphere = isNight ? "夜雾" : "薄雾"
        }
        return "\(flower.name) · \(atmosphere)\(isWindy ? " · 有风" : "")"
    }
}
