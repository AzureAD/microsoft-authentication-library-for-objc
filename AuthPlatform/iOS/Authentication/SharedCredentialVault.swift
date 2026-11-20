import AuthenticationServices
import Foundation
import Security

public struct StoredPasswordCredential: Codable, Equatable {
    public let service: String
    public let username: String
    public let password: String

    public init(service: String, username: String, password: String) {
        self.service = service.lowercased()
        self.username = username
        self.password = password
    }
}

/// Shared Keychain storage used by the host app and Credential Provider Extension.
/// Configure the same Keychain Access Group entitlement on both targets.
public enum SharedCredentialVault {
    private static let keychainService = "com.example.authplatform.credentials"

    private static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "CredentialKeychainAccessGroup") as? String
    }

    @discardableResult
    public static func save(_ credential: StoredPasswordCredential) throws -> Bool {
        guard let data = try? JSONEncoder().encode(credential) else {
            throw VaultError.encodingFailed
        }
        let account = accountKey(service: credential.service, username: credential.username)
        let base = query(account: account, service: credential.service)
        SecItemDelete(base as CFDictionary)
        var attributes = base
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        refreshSystemCredentialIdentities { _ in }
        return true
    }

    public static func credential(service: String, username: String) throws -> StoredPasswordCredential? {
        let account = accountKey(service: service, username: username)
        var attributes = query(account: account, service: service.lowercased())
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.keychain(status) }
        return try JSONDecoder().decode(StoredPasswordCredential.self, from: data)
    }

    public static func credentials(for service: String) throws -> [StoredPasswordCredential] {
        var attributes = query(account: nil, service: service.lowercased())
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let values = result as? [Data] else { throw VaultError.keychain(status) }
        return try values.map { try JSONDecoder().decode(StoredPasswordCredential.self, from: $0) }
    }

    public static func delete(service: String, username: String) throws {
        let status = SecItemDelete(query(account: accountKey(service: service, username: username), service: service.lowercased()) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.keychain(status) }
        let identity = ASPasswordCredentialIdentity(
            serviceIdentifier: ASCredentialServiceIdentifier(identifier: service.lowercased(), type: .domain),
            user: username,
            recordIdentifier: nil
        )
        ASCredentialIdentityStore.shared.removeCredentialIdentities([identity]) { _, _ in }
    }

    public static func allCredentials() throws -> [StoredPasswordCredential] {
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        if let accessGroup { attributes[kSecAttrAccessGroup as String] = accessGroup }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let values = result as? [Data] else { throw VaultError.keychain(status) }
        return try values.map { try JSONDecoder().decode(StoredPasswordCredential.self, from: $0) }
    }

    /// Rebuild the system's local identity index from the unlocked local vault.
    /// The index contains usernames/domains only; passwords remain in Keychain.
    public static func refreshSystemCredentialIdentities(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let items = try allCredentials()
            let identities = items.map { item in
                ASPasswordCredentialIdentity(
                    serviceIdentifier: ASCredentialServiceIdentifier(identifier: item.service, type: .domain),
                    user: item.username,
                    recordIdentifier: nil
                )
            }
            let store = ASCredentialIdentityStore.shared
            store.getState { state in
                guard state.isEnabled else {
                    completion(.success(()))
                    return
                }
                store.saveCredentialIdentities(identities) { _, error in
                    if let error { completion(.failure(error)) }
                    else { completion(.success(())) }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private static func accountKey(service: String, username: String) -> String {
        service.lowercased() + "|" + username.lowercased()
    }

    private static func query(account: String?, service: String) -> [String: Any] {
        var value: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: false
        ]
        if let account { value[kSecAttrAccount as String] = account }
        if let accessGroup { value[kSecAttrAccessGroup as String] = accessGroup }
        return value
    }

    public enum VaultError: Error {
        case encodingFailed
        case keychain(OSStatus)
    }
}
