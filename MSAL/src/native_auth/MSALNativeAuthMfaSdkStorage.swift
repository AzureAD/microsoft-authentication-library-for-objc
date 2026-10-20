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

internal struct MSALNativeAuthMfaSdkAccountRecord: Codable, Sendable {
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

internal struct MSALNativeAuthMfaSdkStoredState: Codable, Sendable {
    var accounts: [MSALNativeAuthMfaSdkAccountRecord] = []
    var currentToken: String?
    var previousToken: String?
    var pendingEnrollment: MSALNativeAuthMfaSdkPendingEnrollment?
    var completedSessionIds: Set<String> = []
}

internal struct MSALNativeAuthMfaSdkPendingEnrollment: Codable, Sendable {
    let id: UUID
    let inputDigest: String
    let token: String
    var activation: MSALNativeAuthMfaSdkXml?
    var validation: MSALNativeAuthMfaSdkXml?
    var validationEndpoint: URL?
    var confirming = false
}

internal protocol MSALNativeAuthMfaSdkStoring: Sendable {
    func load() throws -> MSALNativeAuthMfaSdkStoredState
    func save(_ state: MSALNativeAuthMfaSdkStoredState) throws
}

internal struct MSALNativeAuthMfaSdkKeychain: MSALNativeAuthMfaSdkStoring {
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.microsoft.msal.experimental.mfa.v2",
            kSecAttrAccount as String: "registration-state",
            kSecAttrSynchronizable as String: false
        ]
    }

    func load() throws -> MSALNativeAuthMfaSdkStoredState {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return MSALNativeAuthMfaSdkStoredState() }
        guard status == errSecSuccess else {
            throw MSALNativeAuthMfaSdkServiceError.storageFailure(status: status)
        }
        guard let data = value as? Data else { throw MSALNativeAuthMfaSdkServiceError.invalidResponse }
        do {
            return try JSONDecoder().decode(MSALNativeAuthMfaSdkStoredState.self, from: data)
        } catch {
            throw MSALNativeAuthMfaSdkServiceError.storageFailure(status: errSecDecode)
        }
    }

    func save(_ state: MSALNativeAuthMfaSdkStoredState) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(state)
        } catch {
            throw MSALNativeAuthMfaSdkServiceError.storageFailure(status: errSecParam)
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
            throw MSALNativeAuthMfaSdkServiceError.storageFailure(status: status)
        }
    }
}

internal enum MSALNativeAuthMfaSdkProof {
    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func validation(secret: String, counter: UInt64) throws -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        let input = Array(secret.uppercased().utf8)
        guard !input.isEmpty, input.count <= 1024 else { throw MSALNativeAuthMfaSdkServiceError.invalidResponse }
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
                throw MSALNativeAuthMfaSdkServiceError.invalidResponse
            }
            buffer = (buffer << 5) | UInt32(index)
            bits += 5
            if bits >= 8 {
                bits -= 8
                key.append(UInt8((buffer >> bits) & 255))
            }
            buffer &= (1 << bits) - 1
        }
        guard !key.isEmpty, buffer == 0 else { throw MSALNativeAuthMfaSdkServiceError.invalidResponse }
        let message = Data((0..<8).reversed().map { UInt8((counter >> ($0 * 8)) & 255) })
        let digest = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    static func token(_ data: Data, environment: MSALNativeAuthMfaSdkAPNsEnvironment) throws -> String {
        guard !data.isEmpty, data.count <= 4096 else {
            throw MSALNativeAuthMfaSdkPushRegistrationError.invalidDeviceToken
        }
        let prefix = environment == .sandbox ? "sb-apns2-" : "apns2-"
        return prefix + data.map { String(format: "%02x", $0) }.joined()
    }
}
