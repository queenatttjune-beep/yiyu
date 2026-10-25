import SwiftUI
import YiyuCore

/// The weather beside the date: the sky and the temperature now, today's range below.
/// Before 和风天气 is set up it offers to open the settings.
struct HeaderWeather: View {
    /// Optional, so previews of the panel without weather still draw.
    @Environment(WeatherModel.self) private var weather: WeatherModel?

    var body: some View {
        if let weather {
            Button { WeatherCommand.open() } label: {
                content(weather).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(hint(weather))
            .accessibilityLabel(accessibilityText(weather))
        }
    }

    @ViewBuilder private func content(_ weather: WeatherModel) -> some View {
        if weather.isConfigured, let snapshot = weather.snapshot {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: WeatherSymbol.name(for: snapshot.current.condition.code))
                        .font(.system(size: 15))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.gold)
                    Text("\(Self.degrees(snapshot.current.temperature))°")
                        .font(Theme.serif(19, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                }
                if let today = snapshot.day(containing: weather.now) {
                    Text("\(Self.degrees(today.temperatureMin))–\(Self.degrees(today.temperatureMax))°")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkMuted)
                        .monospacedDigit()
                }
            }
            .opacity(snapshot.isStale(now: weather.now) ? 0.45 : 1)
        } else if weather.isConfigured {
            Image(systemName: weather.problem == nil ? "cloud" : "exclamationmark.icloud")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkFaint)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "cloud.sun")
                Text("设置天气")
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.inkMuted)
        }
    }

    private func hint(_ weather: WeatherModel) -> String {
        guard weather.isConfigured else {
            return "填好和风天气的 API KEY 和城市后，这里会显示天气，今天页会有穿衣建议"
        }
        var lines: [String] = []
        if let snapshot = weather.snapshot, let city = weather.city {
            let now = snapshot.current
            var details = ["\(now.condition.text)", "体感 \(Self.degrees(now.feelsLike))°"]
            if let humidity = now.humidity { details.append("湿度 \(Int((humidity * 100).rounded()))%") }
            if let wind = now.windScale { details.append("风力 \(wind) 级") }
            lines.append(details.joined(separator: " · "))
            lines.append("\(city.name) · \(snapshot.ageLabel(now: weather.now)) · 数据来自和风天气")
        }
        if let problem = weather.problem {
            lines.append("上次没取到：\(problem)")
        }
        lines.append("点一下打开天气设置")
        return lines.joined(separator: "\n")
    }

    private func accessibilityText(_ weather: WeatherModel) -> String {
        guard weather.isConfigured, let snapshot = weather.snapshot else { return "天气设置" }
        return "\(snapshot.current.condition.text) \(Self.degrees(snapshot.current.temperature)) 度"
    }

    static func degrees(_ value: Double) -> Int {
        Int(value.rounded())
    }
}

/// 今日穿衣 on the 今天 page: what to wear and why, until the user closes it for the day.
struct OutfitCard: View {
    @Environment(WeatherModel.self) private var weather: WeatherModel?

    var body: some View {
        if let weather, weather.isConfigured, let advice = weather.visibleAdvice {
            card(advice, weather: weather)
        }
    }

    private func card(_ advice: OutfitAdvice, weather: WeatherModel) -> some View {
        let isStale = weather.snapshot?.isStale(now: weather.now) ?? false
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "tshirt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.gold)
                Text(advice.title)
                    .font(Theme.serif(13, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Spacer(minLength: 4)
                IconButton(systemName: "xmark", help: advice.isToday ? "今天不再显示" : "先收起明天的建议", size: 9) {
                    withAnimation(.easeOut(duration: 0.18)) { weather.hideAdvice() }
                }
            }
            Text(advice.summary)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(footer(advice, weather: weather, isStale: isStale))
                .font(Theme.text(10))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.field))
        .opacity(isStale ? 0.6 : 1)
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    private func footer(_ advice: OutfitAdvice, weather: WeatherModel, isStale: Bool) -> String {
        var parts = [weather.city?.name ?? "", "\(advice.conditionText) \(advice.temperatureMin)–\(advice.temperatureMax)°"]
        if isStale, let snapshot = weather.snapshot {
            parts.append(snapshot.ageLabel(now: weather.now))
        }
        parts.append("数据来自和风天气")
        return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }
}
