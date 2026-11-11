import Foundation
import Security

public protocol CredentialStore: Sendable {
    func load() async throws -> Credentials?
    func save(_ credentials: Credentials) async throws
}

public struct KeychainError: Error, LocalizedError, Sendable {
    public let status: OSStatus
    public var errorDescription: String? {
        "Keychain could not access your credentials (\(status)). Try saving again."
    }
}

public actor KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account = "bandwagon-host"
    public init(service: String = "com.norvyn.KiwiBar") { self.service = service }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private struct Saved: Codable { let veid: String; let apiKey: String }
    public func load() throws -> Credentials? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data else { throw KeychainError(status: errSecDecode) }
        let saved = try JSONDecoder().decode(Saved.self, from: data)
        return try Credentials(veid: saved.veid, apiKey: saved.apiKey)
    }
    public func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(Saved(veid: credentials.veid, apiKey: credentials.apiKey))
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "KiwiBar Bandwagon Host"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess { throw KeychainError(status: status) }
    }
}
