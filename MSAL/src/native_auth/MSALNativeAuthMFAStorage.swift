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
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.microsoft.msal.experimental.mfa.v2",
            kSecAttrAccount as String: "registration-state",
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
