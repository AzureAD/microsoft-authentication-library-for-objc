// ------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// ------------------------------------------------------------------------------

import Foundation
import Security
import CryptoKit

internal struct MSALNativeAuthMFAAccountRecord: Codable, Sendable {
    var id: String
    var name: String
    var username: String
    var secret: String
    var groupKey: String
    var tenantId: String
    var objectId: String
    var endpoint: URL
    var replicationScope: String
    var routingHint: String
    var countryCode: String
    var activatedToken: String
    var dosPreventer: String
    // Absent in legacy registrations; never infer an EEID binding from the current app.
    var bundleId: String?
}

internal struct MSALNativeAuthMFAStoredState: Codable, Sendable {
    var accounts: [MSALNativeAuthMFAAccountRecord] = []
    var currentToken: String?
    var previousToken: String?
    var pendingEnrollment: MSALNativeAuthMFAPendingEnrollment?
    var completedSessionIds: Set<String> = []
    // Optional so older stored state decodes without a migration.
    var tokenChangeAttempts: [String: MSALNativeAuthMFATokenChangeAttempt]?
}

internal struct MSALNativeAuthMFATokenChangeAttempt: Codable, Sendable {
    let id: UUID
    let token: String
}

internal struct MSALNativeAuthMFAPendingEnrollment: Codable, Sendable {
    let id: UUID
    let inputDigest: String
    let token: String
    var activation: MSALNativeAuthSASActivationResult?
    var validation: MSALNativeAuthSASValidationResult?
    var validationEndpoint: URL?
    var confirming = false

    enum CodingKeys: String, CodingKey {
        case id, inputDigest, token, activation, validation, validationEndpoint, confirming
    }
}

// Decode earlier persisted XML without requiring a live SAS client.
extension MSALNativeAuthMFAPendingEnrollment {
    private enum LegacyResponseKey: String, CodingKey { case name }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        inputDigest = try values.decode(String.self, forKey: .inputDigest)
        token = try values.decode(String.self, forKey: .token)
        confirming = try values.decode(Bool.self, forKey: .confirming)
        validationEndpoint = try values.decodeIfPresent(URL.self, forKey: .validationEndpoint)
        if values.contains(.activation), try !values.decodeNil(forKey: .activation) {
            let nested = try values.superDecoder(forKey: .activation)
            if try nested.container(keyedBy: LegacyResponseKey.self).contains(.name) {
                activation = try MSALNativeAuthSASActivationResult(legacyXML: MSALNativeAuthMFAXml(from: nested))
            } else {
                activation = try MSALNativeAuthSASActivationResult(from: nested)
            }
        }
        if values.contains(.validation), try !values.decodeNil(forKey: .validation) {
            let nested = try values.superDecoder(forKey: .validation)
            if try nested.container(keyedBy: LegacyResponseKey.self).contains(.name) {
                validation = try MSALNativeAuthSASValidationResult(legacyXML: MSALNativeAuthMFAXml(from: nested))
            } else {
                validation = try MSALNativeAuthSASValidationResult(from: nested)
            }
        }
    }
}

internal extension MSALNativeAuthSASActivationResult {
    init(legacyXML result: MSALNativeAuthMFAXml) throws {
        let info = try result.child("activationInfo")
        let username = try info.value("Username")
        let secret = try info.value("OathTokenSecretKey")
        let confirmation = try info.value("ConfirmationCode")
        guard !username.isEmpty, !secret.isEmpty, !confirmation.isEmpty else {
            throw MSALNativeAuthMFAFailure.invalidResponse
        }
        try self.init(
            username: username, secret: secret, confirmationCode: confirmation,
            tenantId: info.value("TenantId"), objectId: info.value("AzureObjectId")
        )
    }
}

internal extension MSALNativeAuthSASValidationResult {
    init(legacyXML result: MSALNativeAuthMFAXml) throws {
        let name = try result.value("accountName")
        guard !name.isEmpty else { throw MSALNativeAuthMFAFailure.invalidResponse }
        try self.init(
            username: result.value("username"), accountName: name,
            groupKey: result.optionalValue("groupKey") ?? "", dosPreventer: result.value("dosPreventer")
        )
    }
}

internal protocol MSALNativeAuthMFAStoring: Sendable {
    func load() throws -> MSALNativeAuthMFAStoredState
    func save(_ state: MSALNativeAuthMFAStoredState) throws
}

internal struct MSALNativeAuthMFAKeychain: MSALNativeAuthMFAStoring {
    enum StorageType: String, Sendable {
        case legacy = "registration-state"
        case eeid = "registration-state-eeid"
    }

    private let storageType: StorageType

    init(storageType: StorageType) {
        self.storageType = storageType
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.microsoft.msal.experimental.mfa.v2",
            kSecAttrAccount as String: storageType.rawValue,
            kSecAttrSynchronizable as String: false
        ]
    }

    func load() throws -> MSALNativeAuthMFAStoredState {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return MSALNativeAuthMFAStoredState() }
        guard status == errSecSuccess else {
            throw MSALNativeAuthMFAFailure.storageFailure(status: status)
        }
        guard let data = value as? Data else { throw MSALNativeAuthMFAFailure.invalidResponse }
        do {
            return try JSONDecoder().decode(MSALNativeAuthMFAStoredState.self, from: data)
        } catch {
            throw MSALNativeAuthMFAFailure.storageFailure(status: errSecDecode)
        }
    }

    func save(_ state: MSALNativeAuthMFAStoredState) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(state)
        } catch {
            throw MSALNativeAuthMFAFailure.storageFailure(status: errSecParam)
        }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw MSALNativeAuthMFAFailure.storageFailure(status: status)
        }
    }
}

internal enum MSALNativeAuthMFAProof {
    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func validation(secret: String, counter: UInt64) throws -> String {
        guard !secret.isEmpty else { throw MSALNativeAuthMFAFailure.missingSecretKey }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        let input = Array(secret.uppercased().utf8)
        guard !input.isEmpty, input.count <= 1024 else { throw MSALNativeAuthMFAFailure.invalidResponse }
        var key = Data()
        var buffer: UInt32 = 0
        var bits = 0
        var padding = false
        for character in input {
            if character == 61 {
                padding = true
                continue
            }
            guard !padding, let index = alphabet.firstIndex(of: character) else {
                throw MSALNativeAuthMFAFailure.invalidResponse
            }
            buffer = (buffer << 5) | UInt32(index)
            bits += 5
            if bits >= 8 {
                bits -= 8
                key.append(UInt8((buffer >> bits) & 255))
            }
            buffer &= (1 << bits) - 1
        }
        guard !key.isEmpty, buffer == 0 else { throw MSALNativeAuthMFAFailure.invalidResponse }
        let message = Data((0..<8).reversed().map { UInt8((counter >> ($0 * 8)) & 255) })
        let digest = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    static func token(_ data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) throws -> String {
        guard !data.isEmpty, data.count <= 4096 else {
            throw MSALNativeAuthMFAFailure.invalidDeviceToken
        }
        let prefix = environment == .sandbox ? "sb-apns2-" : "apns2-"
        return prefix + data.map { String(format: "%02x", $0) }.joined()
    }
}
