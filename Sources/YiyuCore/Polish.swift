import Foundation

/// Where to send polish requests: any service that speaks the OpenAI chat-completions API.
public struct AIEndpoint: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String

    public init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    private static let localHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]

    /// Servers on this Mac (such as Ollama) usually need no key.
    public var isLocal: Bool {
        guard let host = parsedBase?.host?.lowercased() else { return false }
        return Self.localHosts.contains(host)
    }

    /// An http(s) address with a host name.
    public var hasValidAddress: Bool {
        parsedBase != nil
    }

    var chatCompletionsURL: URL? {
        guard let base = parsedBase else { return nil }
        if base.path.hasSuffix("/chat/completions") { return base }
        return base.appendingPathComponent("chat").appendingPathComponent("completions")
    }

    private var parsedBase: URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host?.isEmpty == false
        else { return nil }
        return url
    }
}

/// Ready-made settings for common providers; the model name can be edited afterwards.
public struct AIPreset: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let endpoint: AIEndpoint

    public static let all = [
        AIPreset(id: "deepseek", name: "DeepSeek", endpoint: AIEndpoint(baseURL: "https://api.deepseek.com", model: "deepseek-chat")),
        AIPreset(id: "qwen", name: "通义千问", endpoint: AIEndpoint(baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus")),
        AIPreset(id: "kimi", name: "Kimi", endpoint: AIEndpoint(baseURL: "https://api.moonshot.cn/v1", model: "moonshot-v1-8k")),
        AIPreset(id: "zhipu", name: "智谱 GLM", endpoint: AIEndpoint(baseURL: "https://open.bigmodel.cn/api/paas/v4", model: "glm-4-flash")),
        AIPreset(id: "openai", name: "OpenAI", endpoint: AIEndpoint(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini")),
        AIPreset(id: "ollama", name: "本地 Ollama", endpoint: AIEndpoint(baseURL: "http://localhost:11434/v1", model: "qwen2.5:7b")),
    ]
}

public enum PolishError: Error, Equatable, Sendable {
    case invalidAddress
    case missingModel
    case missingKey
    case emptyDiary
    case http(status: Int, message: String?)
    case emptyReply
    case unreadableReply
    case network(String)

    public var userMessage: String {
        switch self {
        case .invalidAddress: return "AI 服务的地址不对，应该以 https:// 或 http:// 开头。"
        case .missingModel: return "还没填模型名。"
        case .missingKey: return "还没填密钥。在 AI 设置里填上服务商给你的 API 密钥。"
        case .emptyDiary: return "这一天还没写内容，先随便写几句再润色。"
        case .emptyReply: return "AI 没有返回内容，再试一次。"
        case .unreadableReply: return "看不懂 AI 服务的回复，检查一下地址是不是 OpenAI 兼容接口。"
        case .network(let detail): return "连不上 AI 服务：\(detail)"
        case .http(let status, let message):
            let detail = message.map { "（\($0)）" } ?? ""
            switch status {
            case 401, 403: return "密钥不对，或者没有权限\(detail)。检查一下 AI 设置里的密钥。"
            case 404: return "找不到这个地址或模型\(detail)。检查地址和模型名。"
            case 429: return "请求太频繁，或者账户额度用完了\(detail)。稍后再试。"
            case 500...599: return "AI 服务暂时出错了（状态码 \(status)）\(detail)，稍后再试。"
            default: return "AI 服务返回了错误（状态码 \(status)）\(detail)。"
            }
        }
    }
}

/// Builds the chat-completions call that rewrites one diary entry in a style.
public enum PolishRequest {
    public static let timeout: TimeInterval = 90
    private static let temperature = 0.8
    private static let maxTokens = 2000

    public static func make(endpoint: AIEndpoint, apiKey: String?, text: String, style: WritingStyle) throws -> URLRequest {
        guard let url = endpoint.chatCompletionsURL else { throw PolishError.invalidAddress }
        let model = endpoint.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw PolishError.missingModel }
        let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty || endpoint.isLocal else { throw PolishError.missingKey }
        let diary = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !diary.isEmpty else { throw PolishError.emptyDiary }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt(for: style)),
                ChatMessage(role: "user", content: diary),
            ],
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    static func systemPrompt(for style: WritingStyle) -> String {
        """
        你是一位中文写作助手，帮用户润色日记。
        风格要求：\(style.instruction)
        规则：
        1. 只依据用户写下的内容润色，不要编造没有发生的事、人物、对话或细节。
        2. 保持第一人称和原来的时间顺序，保留原文的事实和情绪。
        3. 篇幅和原文相近，最多不超过原文的两倍。
        4. 只输出润色后的日记正文，不要标题、解释或引号。
        """
    }

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, stream
            case maxTokens = "max_tokens"
        }
    }
}

/// Reads the polished text out of a chat-completions reply.
public enum PolishResponse {
    public static func text(from data: Data, status: Int) throws -> String {
        guard (200..<300).contains(status) else {
            throw PolishError.http(status: status, message: serviceMessage(in: data))
        }
        guard let reply = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw PolishError.unreadableReply
        }
        let cleaned = clean(reply.choices.first?.message.content ?? "")
        guard !cleaned.isEmpty else { throw PolishError.emptyReply }
        return cleaned
    }

    /// Drops reasoning blocks, code fences and quotes some models wrap around the answer.
    static func clean(_ raw: String) -> String {
        var text = raw.replacing(#/<think>[\s\S]*?</think>/#, with: "")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().joined(separator: "\n")
            if text.hasSuffix("```") { text.removeLast(3) }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (open, close) in [("「", "」"), ("“", "”"), ("\"", "\"")]
        where text.count > 1 && text.hasPrefix(open) && text.hasSuffix(close) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        return text
    }

    private static func serviceMessage(in data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String { return message }
        if let message = json["error"] as? String { return message }
        return json["message"] as? String
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }
}
