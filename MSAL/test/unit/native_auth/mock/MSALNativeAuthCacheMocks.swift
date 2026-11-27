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
@_implementationOnly import MSAL_Unit_Test_Private

class MSALNativeAuthCacheAccessorMock: MSALNativeAuthCacheInterface {
    var tokenCache: MSIDDefaultTokenCacheAccessor
    var accountMetadataCache: MSIDAccountMetadataCacheAccessor

    required init(tokenCache: MSIDDefaultTokenCacheAccessor, accountMetadataCache: MSIDAccountMetadataCacheAccessor) {
        self.tokenCache = tokenCache
        self.accountMetadataCache = accountMetadataCache
    }

    convenience init() {
        let dataSource = MSIDTestCacheDataSource()
        let tokenCache = MSIDDefaultTokenCacheAccessor(dataSource: dataSource, otherCacheAccessors: [])

        let accountMetadataCache = MSIDAccountMetadataCacheAccessor(dataSource: MSIDTestCacheDataSource())

        self.init(tokenCache: tokenCache!, accountMetadataCache: accountMetadataCache!)
    }

    enum E: Error {
        case notImplemented
        case noAccount
        case noTokens
    }

    private(set) var validateAndSaveTokensWasCalled = false
    private(set) var clearCacheWasCalled = false
    private(set) var claimsRequestJsonReceived: String?
    private(set) var saveCallCount = 0
    private(set) var clearCallCount = 0
    var expectedMSIDTokenResult: MSIDTokenResult?
    var validateAndSaveTokensError: Error?
    var mockUserAccounts: [MSALAccount]?
    var mockIdToken: String?

    
    func getIdToken(
        account: MSALAccount, configuration: MSIDConfiguration, context: MSIDRequestContext) throws -> String? {
        guard let mockIdToken = mockIdToken else {
            throw E.noTokens
        }
        return mockIdToken
    }

    func getAllAccounts(configuration: MSIDConfiguration) throws -> [MSALAccount] {
        guard let mockUserAccounts = mockUserAccounts else {
            throw E.noAccount
        }
        return mockUserAccounts
    }

    func validateAndSaveTokensAndAccount(
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext,
        claimsRequestJson: String?
    ) throws -> MSIDTokenResult? {
        validateAndSaveTokensWasCalled = true
        saveCallCount += 1
        claimsRequestJsonReceived = claimsRequestJson
        if let validateAndSaveTokensError {
            throw validateAndSaveTokensError
        }
        return expectedMSIDTokenResult
    }

    func removeTokens(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, clientId: String, context: MSIDRequestContext) throws {
        throw E.notImplemented
    }

    func clearCache(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, clientId: String, context: MSIDRequestContext) throws {
        clearCacheWasCalled = true
        clearCallCount += 1
    }
}

enum MSALNativeAuthTokenResponseFixtures {
    static let targetClaims = "{\"id_token\":{\"xms_agvs\":{\"additionalProperties\":[\"target-mc\"]}}}"
    static let idToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    static let clientInfo = "eyAidWlkIiA6ImZlZGNiYTk4LTc2NTQtMzIxMC0wMDAwLTAwMDAwMDAwMDAwMCIsICJ1dGlkIiA6IjAwMDAwMDAwLTAwMDAtMTIzNC01Njc4LTkwYWJjZGVmZmZmZiJ9"

    static func successfulTokenResponse() throws -> MSALNativeAuthCIAMTokenResponse {
        let response = MSALNativeAuthCIAMTokenResponse()
        response.accessToken = "accessToken"
        response.scope = "openid profile email"
        response.idToken = idToken
        response.clientInfo = try MSIDClientInfo(rawClientInfo: clientInfo)
        response.refreshToken = "refreshToken"
        return response
    }

    static func idToken(receipt: Any?) throws -> String {
        var payload: [String: Any] = ["sub": "1234567890", "name": "John Doe", "iat": 1516239022]
        payload["xms_agvt"] = receipt
        let data = try JSONSerialization.data(withJSONObject: payload)
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(idToken.components(separatedBy: ".")[0]).\(encoded).signature"
    }
}
