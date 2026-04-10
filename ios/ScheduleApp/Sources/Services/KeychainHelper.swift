import Foundation
import Security

// MARK: - Keychain Helper

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
}

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.ymz.schedule-assistant"

    private init() {}

    // MARK: - API Key

    static func saveAPIKey(_ apiKey: String) throws {
        try save(key: "api_key", value: apiKey)
    }

    static func getAPIKey() -> String? {
        return get(key: "api_key")
    }

    static func deleteAPIKey() throws {
        try delete(key: "api_key")
    }

    // MARK: - Private

    private static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Try to delete first (in case of update)
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ymz.schedule-assistant",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ymz.schedule-assistant",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ymz.schedule-assistant",
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
