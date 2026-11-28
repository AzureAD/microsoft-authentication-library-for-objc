import CryptoKit
import Foundation
import Security

/// Client-side vault cryptography. The server receives only AES-GCM envelopes.
enum VaultCryptography {
    static let formatVersion = 1
    private static let keychainService = "com.dabelstech.authplatform.vault-key"
    private static let keychainAccount = "master-key"
    private static let recoveryInfo = Data("AuthPlatform vault recovery v1".utf8)

    struct RecoveryPackage: Codable, Sendable {
        let version: Int
        let salt: String
        let nonce: String
        let ciphertext: String
        let authenticationTag: String
    }

    /// Create a random 256-bit master key and a one-time recovery code.
    /// The caller must display the recovery code and require the user to save it safely.
    static func createVaultKey() throws -> (recoveryCode: String, recoveryPackage: RecoveryPackage) {
        guard !hasVaultKey() else { throw VaultError.keyAlreadyExists }
        let masterKey = SymmetricKey(size: .bits256)
        let recoveryBytes = try secureRandom(count: 32)
        let recoveryCode = recoveryBytes.base64URLEncodedString()
        let salt = try secureRandom(count: 16)
        let wrappingKey = deriveWrappingKey(recoveryCode: recoveryCode, salt: salt)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(masterKey.withUnsafeBytes { Data($0) },
                                      using: wrappingKey,
                                      nonce: nonce,
                                      authenticating: recoveryInfo)
        let package = RecoveryPackage(
            version: formatVersion,
            salt: salt.base64EncodedString(),
            nonce: Data(nonce).base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            authenticationTag: sealed.tag.base64EncodedString()
        )
        try storeMasterKey(masterKey)
        return (recoveryCode, package)
    }

    /// Restore a master key from the user-held recovery code and exported recovery package.
    static func restoreVaultKey(recoveryCode: String, package: RecoveryPackage) throws {
        guard !hasVaultKey() else { throw VaultError.keyAlreadyExists }
        guard package.version == formatVersion,
              let salt = Data(base64Encoded: package.salt),
              salt.count == 16,
              let nonceData = Data(base64Encoded: package.nonce),
              nonceData.count == 12,
              let ciphertext = Data(base64Encoded: package.ciphertext),
              let tag = Data(base64Encoded: package.authenticationTag),
              tag.count == 16,
              let nonce = try? AES.GCM.Nonce(data: nonceData)
        else { throw VaultError.invalidRecoveryPackage }

        let wrappingKey = deriveWrappingKey(recoveryCode: recoveryCode, salt: salt)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let masterData: Data
        do {
            masterData = try AES.GCM.open(box, using: wrappingKey, authenticating: recoveryInfo)
        } catch {
            throw VaultError.recoveryAuthenticationFailed
        }
        guard masterData.count == 32 else { throw VaultError.invalidRecoveryPackage }
        try storeMasterKey(SymmetricKey(data: masterData))
    }

    /// Encrypts a Codable record locally. A fresh AES-GCM nonce is generated per item write.
    static func seal<T: Encodable>(_ value: T, clientItemID: UUID) throws -> EncryptedVaultItemEnvelope {
        let plaintext = try JSONEncoder().encode(value)
        let aad = associatedData(for: clientItemID)
        let box = try AES.GCM.seal(plaintext, using: loadMasterKey(), authenticating: aad)
        return EncryptedVaultItemEnvelope(
            clientItemID: clientItemID,
            ciphertext: box.ciphertext.base64EncodedString(),
            nonce: Data(box.nonce).base64EncodedString(),
            authenticationTag: box.tag.base64EncodedString(),
            formatVersion: formatVersion
        )
    }

    /// Authenticates and decrypts an envelope. Never decode or display data before GCM succeeds.
    static func open<T: Decodable>(_ envelope: EncryptedVaultItemEnvelope, as type: T.Type) throws -> T {
        guard envelope.formatVersion == formatVersion,
              let ciphertext = Data(base64Encoded: envelope.ciphertext),
              let nonceData = Data(base64Encoded: envelope.nonce),
              nonceData.count == 12,
              let tag = Data(base64Encoded: envelope.authenticationTag),
              tag.count == 16,
              let nonce = try? AES.GCM.Nonce(data: nonceData)
        else { throw VaultError.invalidEnvelope }
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(box, using: loadMasterKey(),
                                         authenticating: associatedData(for: envelope.clientItemID))
        } catch {
            throw VaultError.authenticationFailed
        }
        return try JSONDecoder().decode(type, from: plaintext)
    }

    static func hasVaultKey() -> Bool {
        var query = keychainQuery()
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func deleteVaultKey() throws {
        let status = SecItemDelete(keychainQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultError.keychain(status)
        }
    }

    private static func deriveWrappingKey(recoveryCode: String, salt: Data) -> SymmetricKey {
        let input = SymmetricKey(data: Data(recoveryCode.utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: input, salt: salt,
                                      info: recoveryInfo, outputByteCount: 32)
    }

    private static func associatedData(for id: UUID) -> Data {
        Data("AuthPlatform.vault.item.v1:\(id.uuidString.lowercased())".utf8)
    }

    private static func loadMasterKey() throws -> SymmetricKey {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, data.count == 32 else {
            throw VaultError.keyUnavailable(status)
        }
        return SymmetricKey(data: data)
    }

    private static func storeMasterKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query = keychainQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw VaultError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw VaultError.keychain(status)
        }
    }

    private static func keychainQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: false
        ]
        if let group = Bundle.main.object(forInfoDictionaryKey: "CredentialKeychainAccessGroup") as? String {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    private static func secureRandom(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return Data(bytes)
    }

    enum VaultError: LocalizedError {
        case keyAlreadyExists
        case invalidRecoveryPackage
        case recoveryAuthenticationFailed
        case invalidEnvelope
        case authenticationFailed
        case keyUnavailable(OSStatus)
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .keyAlreadyExists: return "A vault master key already exists on this device. Restore or use the existing key instead of replacing it."
            case .invalidRecoveryPackage: return "The vault recovery package is invalid or unsupported."
            case .recoveryAuthenticationFailed: return "The recovery code is incorrect or the recovery package was changed."
            case .invalidEnvelope: return "The encrypted vault item is invalid or unsupported."
            case .authenticationFailed: return "The encrypted vault item failed authentication and was not opened."
            case .keyUnavailable: return "The vault master key is unavailable. Restore it with your recovery code."
            case .keychain: return "The vault key could not be stored securely in Keychain."
            }
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
