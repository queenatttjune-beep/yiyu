import Foundation
import Security

/// Stores one secret string in the login keychain, so API keys never reach the data file,
/// its backups or the repository.
enum KeychainStore {
    struct Failure: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            (SecCopyErrorMessageString(status, nil) as String?) ?? "钥匙串出错（\(status)）"
        }
    }

    /// Checks for the item without reading the secret, so it never triggers a keychain prompt.
    static func exists(service: String, account: String) -> Bool {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func read(service: String, account: String) throws -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves `value`, replacing what was there; an empty value deletes the item.
    /// `label` is what Keychain Access shows for a new item.
    static func save(_ value: String, service: String, account: String, label: String = "一隅 AI 密钥") throws {
        guard !value.isEmpty else {
            try delete(service: service, account: account)
            return
        }
        let data = Data(value.utf8)
        let query = baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw Failure(status: updateStatus) }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = label
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw Failure(status: addStatus) }
    }

    static func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
