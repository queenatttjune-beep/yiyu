import SwiftUI
import YiyuCore

/// Choose the AI service: a preset or any OpenAI-compatible address, a model and a key.
struct AISettingsForm: View {
    let settings: AISettings
    let onDone: @MainActor () -> Void

    @State private var baseURL = ""
    @State private var model = ""
    @State private var key = ""
    @State private var problem: String?

    private var draft: AIEndpoint {
        AIEndpoint(
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var presetName: String {
        AIPreset.all.first { $0.endpoint.baseURL == draft.baseURL }?.name ?? "自己填写"
    }

    private var hasStoredKey: Bool { settings.hasKey(for: draft) }

    private var keyPlaceholder: String {
        if hasStoredKey { return "已为这个地址保存，不改就留空" }
        return draft.isLocal ? "本地模型可以不填" : "服务商给你的 API 密钥"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用你自己的 AI 账号。DeepSeek、通义千问、Kimi、智谱、OpenAI 和本地 Ollama 都可以。")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(AIPreset.all) { preset in
                    Button(preset.name) {
                        baseURL = preset.endpoint.baseURL
                        model = preset.endpoint.model
                    }
                }
            } label: {
                Text("服务：\(presetName)")
                    .font(Theme.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()

            FormField(label: "地址", text: $baseURL, placeholder: "https://…")
            FormField(label: "模型", text: $model, placeholder: "模型名")
            FormField(label: "密钥", text: $key, placeholder: keyPlaceholder, isSecure: true)

            Text("密钥只存在这台 Mac 的钥匙串里，不会写进日记数据。润色时，当天的日记会发给上面的地址。")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkFaint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let problem {
                Text(problem)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.seal)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button("保存", action: save)
                    .buttonStyle(PanelButtonStyle(isPrimary: true))
                if settings.isReady {
                    Button("取消", action: onDone)
                        .buttonStyle(PanelButtonStyle(isPrimary: false))
                }
                Spacer()
                if hasStoredKey {
                    Button("删除这个地址的密钥", action: deleteKey)
                        .buttonStyle(.plain)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
            }
        }
        .onAppear {
            baseURL = settings.endpoint.baseURL
            model = settings.endpoint.model
        }
    }

    private func save() {
        let endpoint = draft
        let typedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !endpoint.hasValidAddress {
            problem = PolishError.invalidAddress.userMessage
        } else if endpoint.isInsecureRemote {
            problem = "连接互联网上的服务要用 https:// 开头的地址；http:// 只适合本机或局域网里的模型。"
        } else if endpoint.model.isEmpty {
            problem = PolishError.missingModel.userMessage
        } else if typedKey.isEmpty && !settings.hasKey(for: endpoint) && !endpoint.isLocal {
            problem = PolishError.missingKey.userMessage
        } else {
            do {
                try settings.save(endpoint: endpoint, newKey: typedKey)
                key = ""
                problem = nil
                onDone()
            } catch {
                problem = "没能保存：\(error.localizedDescription)"
            }
        }
    }

    private func deleteKey() {
        do {
            try settings.deleteKey(for: draft)
            problem = nil
        } catch {
            problem = "没能删除密钥：\(error.localizedDescription)"
        }
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isSecure = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.caption)
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 28, alignment: .leading)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.field))
    }
}

/// Gold for the main action, paper-blue for the rest.
struct PanelButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isPrimary: isPrimary)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let isPrimary: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Theme.text(12.5, weight: .semibold))
                .foregroundStyle(isPrimary ? Theme.paper : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(isPrimary ? Theme.gold : Theme.field))
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
                .contentShape(Rectangle())
        }
    }
}
