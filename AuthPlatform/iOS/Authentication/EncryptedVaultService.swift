import CryptoKit
import Foundation
import Security

/// Bridges the device-only Keychain credential store to the server's opaque
/// AES-GCM envelope API. Plaintext is never passed to AuthPlatformAPI.
enum EncryptedVaultService {
    static func stableItemID(for credential: StoredPasswordCredential) -> UUID {
        let identity = "\(credential.service.lowercased())\u{0}\(credential.username.lowercased())"
        let digest = SHA256.hash(data: Data(identity.utf8))
        var hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        let versionIndex = hex.index(hex.startIndex, offsetBy: 12)
        hex.replaceSubrange(versionIndex...versionIndex, with: "5")
        let variantIndex = hex.index(hex.startIndex, offsetBy: 16)
        hex.replaceSubrange(variantIndex...variantIndex, with: "a")
        let formatted = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20).prefix(12)
        ].map { String($0) }.joined(separator: "-")
        return UUID(uuidString: formatted)!
    }

    /// Pull remote changes first so a server tombstone is applied before a stale
    /// local copy can be uploaded. Every active record is authenticated before save.
    static func synchronize(api: AuthPlatformAPI, accessToken: String) async throws -> Int {
        guard VaultCryptography.hasVaultKey() else {
            throw VaultCryptography.VaultError.keyUnavailable(errSecItemNotFound)
        }

        let remote = try await api.listVaultItems(accessToken: accessToken)
        var changed = 0

        for record in remote {
            if record.isDeleted {
                if let credential = try findLocalCredential(for: record.clientItemID) {
                    try SharedCredentialVault.delete(service: credential.service, username: credential.username)
                    changed += 1
                }
                continue
            }

            let envelope = EncryptedVaultItemEnvelope(
                clientItemID: record.clientItemID,
                ciphertext: record.ciphertext,
                nonce: record.nonce,
                authenticationTag: record.authenticationTag,
                formatVersion: record.formatVersion
            )
            let credential = try VaultCryptography.open(envelope, as: StoredPasswordCredential.self)
            guard !credential.service.isEmpty, !credential.username.isEmpty else {
                throw SyncError.invalidCredential
            }
            if try SharedCredentialVault.credential(service: credential.service, username: credential.username) != credential {
                try SharedCredentialVault.save(credential)
                changed += 1
            }
        }

        // Re-read after applying remote changes. This uploads new local items and
        // updates changed local values, always as authenticated ciphertext envelopes.
        for credential in try SharedCredentialVault.allCredentials() {
            let id = stableItemID(for: credential)
            let envelope = try VaultCryptography.seal(credential, clientItemID: id)
            _ = try await api.saveVaultItem(envelope, accessToken: accessToken)
        }
        return changed
    }

    /// Commit the server tombstone before removing the local copy. If the network
    /// request fails, the local credential remains available rather than being lost
    /// while another device can still restore the remote copy.
    static func delete(_ credential: StoredPasswordCredential, api: AuthPlatformAPI, accessToken: String) async throws {
        let id = stableItemID(for: credential)
        try await api.deleteVaultItem(clientItemID: id, accessToken: accessToken)
        try SharedCredentialVault.delete(service: credential.service, username: credential.username)
    }

    private static func findLocalCredential(for itemID: UUID) throws -> StoredPasswordCredential? {
        try SharedCredentialVault.allCredentials().first {
            stableItemID(for: $0) == itemID
        }
    }

    enum SyncError: LocalizedError {
        case invalidCredential

        var errorDescription: String? {
            "A decrypted vault record did not contain a valid credential. No data was uploaded."
        }
    }
}
