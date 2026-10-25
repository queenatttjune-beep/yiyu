import Foundation
import Observation
import YiyuCore

/// Which AI service polishes the diary. The address and model live in UserDefaults;
/// the API key lives only in the keychain.
@MainActor
@Observable
final class AISettings {
    private static let endpointKey = "ai.endpoint"
    private static let keyAccount = "api-key"

    private(set) var endpoint: AIEndpoint
    private(set) var hasKey: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychainService: String

    init(defaults: UserDefaults = .standard, bundleID: String = Bundle.main.bundleIdentifier ?? "yiyu") {
        let service = "\(bundleID).ai"
        let stored = defaults.data(forKey: Self.endpointKey).flatMap { try? JSONDecoder().decode(AIEndpoint.self, from: $0) }
        self.defaults = defaults
        self.keychainService = service
        self.endpoint = stored ?? AIPreset.all[0].endpoint
        self.hasKey = KeychainStore.exists(service: service, account: Self.keyAccount)
        self.isSaved = stored != nil
        #if DEBUG
        applyTourOverride()
        #endif
    }

    /// True once the user has saved settings at least once.
    private(set) var isSaved: Bool

    var isReady: Bool {
        isSaved && (hasKey || endpoint.isLocal)
    }

    func apiKey() throws -> String? {
        try KeychainStore.read(service: keychainService, account: Self.keyAccount)
    }

    /// Saves the address and model. A blank `newKey` keeps the key already stored.
    func save(endpoint: AIEndpoint, newKey: String) throws {
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try KeychainStore.save(trimmedKey, service: keychainService, account: Self.keyAccount)
            hasKey = true
        }
        defaults.set(try JSONEncoder().encode(endpoint), forKey: Self.endpointKey)
        self.endpoint = endpoint
        isSaved = true
    }

    func deleteKey() throws {
        try KeychainStore.delete(service: keychainService, account: Self.keyAccount)
        hasKey = false
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
