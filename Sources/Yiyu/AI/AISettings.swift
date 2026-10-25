import Foundation
import Observation
import YiyuCore

/// Which AI service polishes the diary. The address and model live in UserDefaults; API keys
/// live only in the keychain, one per host, so a key is never sent to a different service.
@MainActor
@Observable
final class AISettings {
    private static let endpointKey = "ai.endpoint"

    private(set) var endpoint: AIEndpoint
    /// Whether a key is stored for the current endpoint's host.
    private(set) var hasKey: Bool
    /// True once the user has saved settings at least once.
    private(set) var isSaved: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychainService: String

    init(defaults: UserDefaults = .standard, bundleID: String = Bundle.main.bundleIdentifier ?? "yiyu") {
        let service = "\(bundleID).ai"
        let stored = defaults.data(forKey: Self.endpointKey).flatMap { try? JSONDecoder().decode(AIEndpoint.self, from: $0) }
        let endpoint = stored ?? AIPreset.all[0].endpoint
        self.defaults = defaults
        self.keychainService = service
        self.endpoint = endpoint
        self.hasKey = KeychainStore.exists(service: service, account: endpoint.keyAccount)
        self.isSaved = stored != nil
        #if DEBUG
        applyTourOverride()
        #endif
    }

    var isReady: Bool {
        isSaved && (hasKey || endpoint.isLocal)
    }

    func hasKey(for endpoint: AIEndpoint) -> Bool {
        KeychainStore.exists(service: keychainService, account: endpoint.keyAccount)
    }

    /// Reads the current endpoint's key. Call it off the main thread: macOS may show a
    /// keychain prompt, and the panel must not freeze behind it.
    func keyReader() -> @Sendable () throws -> String? {
        let service = keychainService
        let account = endpoint.keyAccount
        return { try KeychainStore.read(service: service, account: account) }
    }

    /// Saves the address and model; a non-blank `newKey` is filed under that address's host.
    func save(endpoint: AIEndpoint, newKey: String) throws {
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try KeychainStore.save(trimmedKey, service: keychainService, account: endpoint.keyAccount)
        }
        defaults.set(try JSONEncoder().encode(endpoint), forKey: Self.endpointKey)
        self.endpoint = endpoint
        hasKey = hasKey(for: endpoint)
        isSaved = true
    }

    func deleteKey(for endpoint: AIEndpoint) throws {
        try KeychainStore.delete(service: keychainService, account: endpoint.keyAccount)
        hasKey = hasKey(for: self.endpoint)
    }

    #if DEBUG
    /// The UI tour points the app at a fake local server instead of a real AI service.
    private func applyTourOverride() {
        guard let url = ProcessInfo.processInfo.environment["YIYU_TOUR_AI_URL"] else { return }
        endpoint = AIEndpoint(baseURL: url, model: "mock")
        isSaved = true
    }
    #endif
}
