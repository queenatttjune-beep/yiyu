/// The SF Symbol for a 和风天气 weather code (https://dev.qweather.com/docs/resource/icons/).
/// Codes 150–157 and 350–351, 456–457 are the night-time versions.
public enum WeatherSymbol {
    private static let fallback = "thermometer.medium"

    public static func name(for code: String) -> String {
        guard let number = Int(code) else { return fallback }
        switch number {
        case 100: return "sun.max"
        case 150: return "moon.stars"
        case 101...103: return "cloud.sun"
        case 151...153: return "cloud.moon"
        case 104: return "cloud"
        case 300, 301: return "cloud.sun.rain"
        case 350, 351: return "cloud.moon.rain"
        case 302...304: return "cloud.bolt.rain"
        case 305, 309: return "cloud.drizzle"
        case 306, 314, 315, 399: return "cloud.rain"
        case 307, 308, 310...312, 316...318: return "cloud.heavyrain"
        case 313, 404...406, 456: return "cloud.sleet"
        case 400...403, 407...410, 457, 499: return "cloud.snow"
        case 500, 501, 509, 510, 514, 515: return "cloud.fog"
        case 502, 511...513: return "sun.haze"
        case 503...508: return "sun.dust"
        case 900: return "thermometer.sun"
        case 901: return "thermometer.snowflake"
        default: return fallback
        }
    }
}
