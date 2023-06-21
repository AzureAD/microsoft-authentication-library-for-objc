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

final class MSALNativeAuthResultFactoryTests: XCTestCase {

    private var sut: MSALNativeAuthResultFactory!

    private let tokenResponseDict: [String: Any] = [
        "token_type": "Bearer",
        "scope": "openid profile email",
        "expires_in": 4141,
        "ext_expires_in": 4141,
        "access_token": "accessToken",
        "refresh_token": "refreshToken",
        "id_token": "idToken"
    ]

    override func setUpWithError() throws {
        sut = .init(config: MSALNativeAuthConfigStubs.configuration)
    }

    func test_makeMsidConfiguration() {
        let result = sut.makeMSIDConfiguration(scopes: ["<scope_1>", "<scope_2>"])

        XCTAssertEqual(result.authority, MSALNativeAuthNetworkStubs.msidAuthority)
        XCTAssertNil(result.redirectUri)
        XCTAssertEqual(result.clientId, DEFAULT_TEST_CLIENT_ID)
        XCTAssertEqual(result.target, "<scope_1> <scope_2>")
    }
    
    func test_makeUserAccount_returnExpectedResult() {
        let accessTokenString = "accessToken"
        let idToken = "idToken"
        let username = "username"
        let scopes = ["scope1", "scope2"]
        let expiresOn = Date()
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = accessTokenString
        accessToken.accountIdentifier = MSIDAccountIdentifier(displayableId: username, homeAccountId: "")
        accessToken.expiresOn = expiresOn
        accessToken.scopes = NSOrderedSet(array: scopes)
        let refreshToken = MSIDRefreshToken()
        refreshToken.refreshToken = "refreshToken"
        let msidAccount = MSIDAccount()
        msidAccount.username = username
        guard let tokenResult = MSIDTokenResult(accessToken: accessToken, refreshToken: refreshToken, idToken: idToken, account: msidAccount, authority: MSALNativeAuthNetworkStubs.msidAuthority, correlationId: UUID(), tokenResponse: nil) else {
            XCTFail("Unexpected nil token")
            return
        }
        let context = MSALNativeAuthRequestContext(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        guard let account = sut.makeUserAccountResult(tokenResult: tokenResult, context: context) else {
            XCTFail("Unexpected nil account")
            return
        }
        XCTAssertEqual(account.username, username)
        XCTAssertEqual(account.idToken, idToken)
        XCTAssertEqual(account.expiresOn, expiresOn)
        XCTAssertEqual(account.scopes, scopes)
    }
}
