import Foundation
import Testing
@testable import YiyuCore

struct PolishRequestTests {
    let endpoint = AIEndpoint(baseURL: "https://api.deepseek.com/", model: "deepseek-chat")
    let poetic = WritingStyle.builtIns[1]

    private func body(of request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func buildsAChatCompletionsCall() throws {
        let request = try PolishRequest.make(endpoint: endpoint, apiKey: "sk-test", text: "今天去公园了。", style: poetic)

        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try body(of: request)
        #expect(json["model"] as? String == "deepseek-chat")
        #expect(json["stream"] as? Bool == false)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["system", "user"])
        #expect(messages[0]["content"]?.contains(poetic.instruction) == true)
        #expect(messages[0]["content"]?.contains("不要编造") == true)
        #expect(messages[1]["content"] == "今天去公园了。")
    }

    @Test func keepsAFullChatCompletionsAddress() throws {
        let full = AIEndpoint(baseURL: "https://example.com/v1/chat/completions", model: "m")
        let request = try PolishRequest.make(endpoint: full, apiKey: "k", text: "a", style: poetic)
        #expect(request.url?.absoluteString == "https://example.com/v1/chat/completions")
    }

    @Test func addressValidation() {
        #expect(endpoint.hasValidAddress)
        #expect(AIEndpoint(baseURL: "http://localhost:11434/v1", model: "m").hasValidAddress)
        #expect(!AIEndpoint(baseURL: "api.deepseek.com", model: "m").hasValidAddress)
        #expect(!AIEndpoint(baseURL: "ftp://example.com", model: "m").hasValidAddress)
        #expect(!AIEndpoint(baseURL: "", model: "m").hasValidAddress)
    }

    @Test func localServersNeedNoKey() throws {
        let local = AIEndpoint(baseURL: "http://localhost:11434/v1", model: "qwen2.5")
        let request = try PolishRequest.make(endpoint: local, apiKey: nil, text: "a", style: poetic)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(local.isLocal)
        #expect(!endpoint.isLocal)
    }

    @Test func rejectsIncompleteSettingsAndEmptyDiaries() {
        #expect(throws: PolishError.invalidAddress) {
            try PolishRequest.make(endpoint: AIEndpoint(baseURL: "not a url", model: "m"), apiKey: "k", text: "a", style: poetic)
        }
        #expect(throws: PolishError.missingModel) {
            try PolishRequest.make(endpoint: AIEndpoint(baseURL: "https://a.com", model: " "), apiKey: "k", text: "a", style: poetic)
        }
        #expect(throws: PolishError.missingKey) {
            try PolishRequest.make(endpoint: endpoint, apiKey: "  ", text: "a", style: poetic)
        }
        #expect(throws: PolishError.emptyDiary) {
            try PolishRequest.make(endpoint: endpoint, apiKey: "k", text: " \n ", style: poetic)
        }
    }

    @Test func presetsCoverCommonProviders() {
        let names = AIPreset.all.map(\.name)
        #expect(names.contains("DeepSeek"))
        #expect(names.contains("本地 Ollama"))
        #expect(AIPreset.all.allSatisfy { URL(string: $0.endpoint.baseURL)?.scheme != nil && !$0.endpoint.model.isEmpty })
    }
}

struct PolishResponseTests {
    private func reply(_ content: String) -> Data {
        let payload: [String: Any] = ["choices": [["message": ["role": "assistant", "content": content]]]]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    @Test func readsTheFirstChoice() throws {
        #expect(try PolishResponse.text(from: reply("  秋风渐起。\n"), status: 200) == "秋风渐起。")
    }

    @Test func stripsThinkingFencesAndWrappingQuotes() throws {
        #expect(try PolishResponse.text(from: reply("<think>想一想</think>\n秋风渐起。"), status: 200) == "秋风渐起。")
        #expect(try PolishResponse.text(from: reply("```\n秋风渐起。\n```"), status: 200) == "秋风渐起。")
        #expect(try PolishResponse.text(from: reply("「秋风渐起。」"), status: 200) == "秋风渐起。")
    }

    @Test func emptyOrMalformedRepliesAreErrors() {
        #expect(throws: PolishError.emptyReply) { try PolishResponse.text(from: reply("   "), status: 200) }
        #expect(throws: PolishError.unreadableReply) { try PolishResponse.text(from: Data("oops".utf8), status: 200) }
    }

    @Test func httpErrorsCarryTheServiceMessage() {
        let body = Data(#"{"error": {"message": "Invalid API key"}}"#.utf8)
        #expect(throws: PolishError.http(status: 401, message: "Invalid API key")) {
            try PolishResponse.text(from: body, status: 401)
        }
        #expect(throws: PolishError.http(status: 502, message: nil)) {
            try PolishResponse.text(from: Data("<html>".utf8), status: 502)
        }
    }

    @Test func errorsReadAsPlainChinese() {
        #expect(PolishError.http(status: 401, message: nil).userMessage.contains("密钥"))
        #expect(PolishError.http(status: 404, message: nil).userMessage.contains("模型"))
        #expect(PolishError.http(status: 429, message: nil).userMessage.contains("额度"))
        #expect(PolishError.http(status: 500, message: "boom").userMessage.contains("500"))
        #expect(PolishError.missingKey.userMessage.contains("密钥"))
    }
}
