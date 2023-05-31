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

    func test_makeNativeAuthResponse() {
        let expirationDate = Date()

        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "<access_token>"
        accessToken.scopes = []
        accessToken.expiresOn = expirationDate

        let idToken = "<id_token>"

        let tokenResult = MSIDTokenResult(
            accessToken: accessToken,
            refreshToken: MSIDRefreshToken(),
            idToken: idToken,
            account: MSIDAccount(),
            authority: MSALNativeAuthNetworkStubs.msidAuthority,
            correlationId: UUID(uuidString: DEFAULT_TEST_UID)!,
            tokenResponse: nil
        )!

        let result = sut.makeNativeAuthResponse(
            stage: .completed,
            credentialToken: nil,
            tokenResult: tokenResult
        )

        XCTAssertEqual(result.stage, .completed)
        XCTAssertNil(result.credentialToken)
        XCTAssertEqual(result.authentication?.accessToken, "<access_token>")
        XCTAssertEqual(result.authentication?.idToken, idToken)
        XCTAssertEqual(result.authentication?.scopes, [])
        XCTAssertEqual(result.authentication?.expiresOn, expirationDate)
        XCTAssertEqual(result.authentication?.tenantId, MSALNativeAuthNetworkStubs.tenantName)
    }

    func test_makeResponse_withIncorrectScopes_should_fix_it() {
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "<access_token>"
        accessToken.scopes = ["<scope_1> <scope_2>"] // instead of two strings, the user passes one single string with scopes separated by a comma
        accessToken.expiresOn = Date()

        let tokenResult = MSIDTokenResult(
            accessToken: accessToken,
            refreshToken: MSIDRefreshToken(),
            idToken: "",
            account: MSIDAccount(),
            authority: MSALNativeAuthNetworkStubs.msidAuthority,
            correlationId: UUID(uuidString: DEFAULT_TEST_UID)!,
            tokenResponse: nil
        )!

        let result = sut.makeNativeAuthResponse(
            stage: .completed,
            credentialToken: nil,
            tokenResult: tokenResult
        )
        XCTAssertEqual(result.authentication?.scopes, ["<scope_1>", "<scope_2>"])
    }

    func test_makeResponse_withCorrectScopes() {
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "<access_token>"
        accessToken.scopes = ["<scope_1>", "<scope_2>"]
        accessToken.expiresOn = Date()

        let tokenResult = MSIDTokenResult(
            accessToken: accessToken,
            refreshToken: MSIDRefreshToken(),
            idToken: "",
            account: MSIDAccount(),
            authority: MSALNativeAuthNetworkStubs.msidAuthority,
            correlationId: UUID(uuidString: DEFAULT_TEST_UID)!,
            tokenResponse: nil
        )!

        let result = sut.makeNativeAuthResponse(
            stage: .completed,
            credentialToken: nil,
            tokenResult: tokenResult
        )
        XCTAssertEqual(result.authentication?.scopes, ["<scope_1>", "<scope_2>"])
    }

    func test_makeMsidConfiguration() {
        let result = sut.makeMSIDConfiguration(scope: ["<scope_1>", "<scope_2>"])

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
        guard let tokenResult = MSIDTokenResult(accessToken: accessToken, refreshToken: nil, idToken: idToken, account: MSIDAccount(), authority: MSALNativeAuthNetworkStubs.msidAuthority, correlationId: UUID(), tokenResponse: nil) else {
            XCTFail("Unexpected nil token")
            return
        }
        let account = sut.makeUserAccount(tokenResult: tokenResult)
        XCTAssertEqual(account.accessToken, accessTokenString)
        XCTAssertEqual(account.username, username)
        XCTAssertEqual(account.rawIdToken, idToken)
        XCTAssertEqual(account.expiresOn, expiresOn)
        XCTAssertEqual(account.scopes, scopes)
    }
}
