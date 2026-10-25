import SwiftUI
import YiyuCore

/// 天气设置: the 和风天气 account, the city, the morning outfit notification and whether the
/// panel follows the weather.
struct WeatherSettingsView: View {
    private static let consoleURL = URL(string: "https://console.qweather.com")

    let model: WeatherModel

    @State private var host: String
    @State private var newKey = ""
    @State private var query = ""
    @State private var results: [WeatherCity] = []
    @State private var city: WeatherCity?
    @State private var isBriefingOn: Bool
    @State private var briefingTime: Date
    @State private var showsScene: Bool
    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var saveMessage: String?

    init(model: WeatherModel) {
        self.model = model
        let settings = model.settings
        _host = State(initialValue: settings.apiHost)
        _city = State(initialValue: settings.city)
        _isBriefingOn = State(initialValue: settings.briefing.isEnabled)
        _briefingTime = State(initialValue: Self.time(hour: settings.briefing.hour, minute: settings.briefing.minute))
        _showsScene = State(initialValue: settings.showsScene)
    }

    var body: some View {
        Form {
            accountSection
            citySection
            briefingSection
            sceneSection
            statusSection
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 720)
    }

    private var accountSection: some View {
        Section {
            TextField("API Host", text: $host, prompt: Text("例如 abcxyz.qweatherapi.com"))
            SecureField("API KEY", text: $newKey, prompt: Text(model.hasKey ? "已存在钥匙串里，留空就不变" : "粘贴 API KEY"))
        } header: {
            Text("和风天气账号")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("在和风天气控制台创建项目并添加 API KEY 凭据；API Host 在控制台的「设置」里。密钥只存在这台 Mac 的钥匙串里，不会写进数据文件。")
                if let console = Self.consoleURL {
                    Link("打开和风天气控制台", destination: console)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var citySection: some View {
        Section("城市") {
            HStack {
                TextField("搜索", text: $query, prompt: Text("输入城市名，例如 杭州"))
                    .onSubmit(search)
                Button("搜索", action: search)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
            }
            if isSearching {
                ProgressView().controlSize(.small)
            }
            if let searchMessage {
                Text(searchMessage).font(.callout).foregroundStyle(.secondary)
            }
            ForEach(results) { result in
                Button { city = result } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                            if !result.region.isEmpty {
                                Text(result.region).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if city?.id == result.id {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            LabeledContent("已选", value: city.map(Self.describe) ?? "还没选")
        }
    }

    private var briefingSection: some View {
        Section {
            Toggle("每天早上发一条穿衣建议", isOn: $isBriefingOn)
            DatePicker("时间", selection: $briefingTime, displayedComponents: .hourAndMinute)
                .disabled(!isBriefingOn)
        } header: {
            Text("早晨提醒")
        } footer: {
            Text("到点时现取预报再发。那时电脑在睡眠的话，会在中午前第一次唤醒时补发。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sceneSection: some View {
        Section {
            Toggle("面板跟着天气变化", isOn: $showsScene)
        } header: {
            Text("天气氛围")
        } footer: {
            Text("下雨时面板上飘着蒙蒙细雨，晴天洒着阳光，晴夜有月光和星星，下雪、起雾也会画出来；收起时的小圆标和菜单栏图标也跟着变。系统设置里打开「减弱动态效果」时，画面是静止的。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        Section {
            if let message = saveMessage ?? model.problem ?? model.storageProblem {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if model.isRefreshing {
                Label("正在获取天气…", systemImage: "arrow.triangle.2.circlepath")
            } else if let snapshot = model.snapshot, let saved = model.city {
                Label("\(saved.name)：\(snapshot.current.condition.text) \(Int(snapshot.current.temperature.rounded()))°，\(snapshot.ageLabel(now: model.now))",
                      systemImage: WeatherSymbol.name(for: snapshot.current.condition.code, atNight: model.isNight))
            }
            HStack {
                Text(missingHint ?? "天气数据来自和风天气").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(missingHint != nil)
            }
        }
    }

    /// What still has to be filled in before saving makes sense.
    private var missingHint: String? {
        if QWeatherAPI(host: host) == nil { return "API Host 应该形如 abcxyz.qweatherapi.com" }
        if !model.hasKey && newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "还没填 API KEY" }
        if city == nil { return "搜索并选一个城市" }
        return nil
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSearching else { return }
        isSearching = true
        searchMessage = nil
        Task {
            defer { isSearching = false }
            do {
                results = try await model.searchCities(text, host: host, newKey: newKey)
                searchMessage = results.isEmpty ? "没找到「\(text)」，换个写法试试" : nil
            } catch {
                results = []
                searchMessage = WeatherFailure(error).userMessage
            }
        }
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: briefingTime)
        let briefing = BriefingSchedule(isEnabled: isBriefingOn, hour: parts.hour ?? 7, minute: parts.minute ?? 30)
        do {
            try model.save(host: host, newKey: newKey, city: city, briefing: briefing, showsScene: showsScene)
            newKey = ""
            saveMessage = nil
        } catch {
            saveMessage = "没能把密钥存进钥匙串：\(error.localizedDescription)"
        }
    }

    private static func describe(_ city: WeatherCity) -> String {
        city.region.isEmpty ? city.name : "\(city.name)，\(city.region)"
    }

    private static func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
