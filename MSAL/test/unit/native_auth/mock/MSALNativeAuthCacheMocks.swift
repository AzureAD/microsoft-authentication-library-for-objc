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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthCacheAccessorMock: MSALNativeAuthCacheInterface {
    var tokenCache: MSIDDefaultTokenCacheAccessor
    var accountMetadataCache: MSIDAccountMetadataCacheAccessor

    required init(tokenCache: MSIDDefaultTokenCacheAccessor, accountMetadataCache: MSIDAccountMetadataCacheAccessor) {
        self.tokenCache = tokenCache
        self.accountMetadataCache = accountMetadataCache
    }

    convenience init() {
        let dataSource = MSIDKeychainTokenCache()
        let tokenCache = MSIDDefaultTokenCacheAccessor(dataSource: dataSource, otherCacheAccessors: [])

        let accountMetadataCache = MSIDAccountMetadataCacheAccessor(dataSource: MSIDKeychainTokenCache())

        self.init(tokenCache: tokenCache!, accountMetadataCache: accountMetadataCache!)
    }

    enum E: Error {
        case notImplemented
        case noAccount
        case noTokens
    }

    private(set) var validateAndSaveTokensWasCalled = false
    private(set) var clearCacheWasCalled = false
    var expectedMSIDTokenResult: MSIDTokenResult?
    var mockUserAccounts: [MSALAccount]?
    var mockAuthTokens: MSALNativeAuthTokens?

    func getTokens(account: MSALAccount, configuration: MSIDConfiguration, context: MSIDRequestContext) throws -> MSAL.MSALNativeAuthTokens {
        guard let mockAuthTokens = mockAuthTokens else {
            throw E.noTokens
        }
        return mockAuthTokens
    }

    func getAllAccounts(configuration: MSIDConfiguration) throws -> [MSALAccount] {
        guard let mockUserAccounts = mockUserAccounts else {
            throw E.noAccount
        }
        return mockUserAccounts
    }

    func validateAndSaveTokensAndAccount(tokenResponse: MSIDTokenResponse, configuration: MSIDConfiguration, context: MSIDRequestContext) throws -> MSIDTokenResult? {
        validateAndSaveTokensWasCalled = true
        return expectedMSIDTokenResult
    }

    func removeTokens(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, clientId: String, context: MSIDRequestContext) throws {
        throw E.notImplemented
    }

    func clearCache(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, clientId: String, context: MSIDRequestContext) throws {
        clearCacheWasCalled = true
    }
}
