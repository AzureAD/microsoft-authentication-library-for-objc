import XCTest
@testable import AuthPlatform

final class VaultCryptographyTests: XCTestCase {
    override func setUpWithError() throws {
        if VaultCryptography.hasVaultKey() {
            try VaultCryptography.deleteVaultKey()
        }
    }

    override func tearDownWithError() throws {
        if VaultCryptography.hasVaultKey() {
            try VaultCryptography.deleteVaultKey()
        }
    }

    func testRecoveryPackageRestoresKeyAndDecryptsExistingEnvelope() throws {
        let created = try VaultCryptography.createVaultKey()
        let credential = StoredPasswordCredential(
            service: "example.com",
            username: "alice",
            password: "test-password"
        )
        let itemID = EncryptedVaultService.stableItemID(for: credential)
        let envelope = try VaultCryptography.seal(credential, clientItemID: itemID)

        try VaultCryptography.deleteVaultKey()
        try VaultCryptography.restoreVaultKey(
            recoveryCode: created.recoveryCode,
            package: created.recoveryPackage
        )

        XCTAssertEqual(
            try VaultCryptography.open(envelope, as: StoredPasswordCredential.self),
            credential
        )
    }

    func testWrongRecoveryCodeDoesNotInstallAKey() throws {
        let created = try VaultCryptography.createVaultKey()
        try VaultCryptography.deleteVaultKey()

        XCTAssertThrowsError(
            try VaultCryptography.restoreVaultKey(
                recoveryCode: "incorrect recovery code",
                package: created.recoveryPackage
            )
        )
        XCTAssertFalse(VaultCryptography.hasVaultKey())
    }

    func testTamperedCiphertextIsRejected() throws {
        _ = try VaultCryptography.createVaultKey()
        let credential = StoredPasswordCredential(
            service: "example.com",
            username: "alice",
            password: "test-password"
        )
        let original = try VaultCryptography.seal(
            credential,
            clientItemID: EncryptedVaultService.stableItemID(for: credential)
        )
        let tamperedCiphertext = (original.ciphertext.first == "A" ? "B" : "A")
            + original.ciphertext.dropFirst()
        let tampered = EncryptedVaultItemEnvelope(
            clientItemID: original.clientItemID,
            ciphertext: tamperedCiphertext,
            nonce: original.nonce,
            authenticationTag: original.authenticationTag,
            formatVersion: original.formatVersion
        )

        XCTAssertThrowsError(
            try VaultCryptography.open(tampered, as: StoredPasswordCredential.self)
        )
    }

    func testRestoreCannotOverwriteAnExistingVaultKey() throws {
        let created = try VaultCryptography.createVaultKey()

        XCTAssertThrowsError(
            try VaultCryptography.restoreVaultKey(
                recoveryCode: created.recoveryCode,
                package: created.recoveryPackage
            )
        )
        XCTAssertTrue(VaultCryptography.hasVaultKey())
    }

    func testCredentialItemIdentifierIsStableAndScopedToIdentity() {
        let first = StoredPasswordCredential(service: "example.com", username: "alice", password: "one")
        let sameIdentity = StoredPasswordCredential(service: "EXAMPLE.COM", username: "ALICE", password: "two")
        let otherIdentity = StoredPasswordCredential(service: "example.com", username: "bob", password: "one")

        XCTAssertEqual(
            EncryptedVaultService.stableItemID(for: first),
            EncryptedVaultService.stableItemID(for: sameIdentity)
        )
        XCTAssertNotEqual(
            EncryptedVaultService.stableItemID(for: first),
            EncryptedVaultService.stableItemID(for: otherIdentity)
        )
    }
}
