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
            throw MSALNativeAuthMFAError.Reason.storageFailure(status: status)
        }
        guard let data = value as? Data else { throw MSALNativeAuthMFAError.Reason.invalidResponse }
        do {
            return try JSONDecoder().decode(MSALNativeAuthMFAStoredState.self, from: data)
        } catch {
            throw MSALNativeAuthMFAError.Reason.storageFailure(status: errSecDecode)
        }
    }

    func save(_ state: MSALNativeAuthMFAStoredState) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(state)
        } catch {
            throw MSALNativeAuthMFAError.Reason.storageFailure(status: errSecParam)
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
            throw MSALNativeAuthMFAError.Reason.storageFailure(status: status)
        }
    }
}
