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
        sut = .init(config: MSALNativeAuthConfigStubs.configuration, cacheAccessor: MSALNativeAuthCacheAccessorMock())
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
        let idToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ii1LSTNROW5OUjdiUm9meG1lWm9YcWJIWkdldyJ9.eyJhdWQiOiJmODdmN2Q2NS1jZjY2LTQzNzAtYTllZi0yNGQzNzBlZDllNjQiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vZmU2MjYwOTYtZWQ5Ny00NTA0LTg4ZTMtNTVhMzNkMmVkNGQ2L3YyLjAiLCJpYXQiOjE2OTUwMzMzMDYsIm5iZiI6MTY5NTAzMzMwNiwiZXhwIjoxNjk1MDM3MjA2LCJhaW8iOiJBVFFBeS84VUFBQUFyeVNpU1Rsa0dHNTl0VHFmcWdHU1ZZRWY4RzRQbldDSnlUZ2hXdzdDU2MvRGZwMWxYRXI0T1JTWFBJbzdzaldnIiwibmFtZSI6InVua25vd24iLCJvaWQiOiIzYzIwZWM4Zi0xNzVkLTQxMjgtODZhMy01MDM5MDRhNDRiMTUiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJkdWFsdGFnaG1zZnQrc2lnbnVwMzFAb3V0bG9vay5jb20iLCJyaCI6IjAuQWM4QWxtQmlfcGZ0QkVXSTQxV2pQUzdVMW1WOWZfaG16M0JEcWU4azAzRHRubVRQQUJJLiIsInN1YiI6ImcwLTc0U3hHUnhSTjBqT19hXzY4bG9adGVsY1EwdTJFX3hyYmNBaGRtWjAiLCJ0aWQiOiJmZTYyNjA5Ni1lZDk3LTQ1MDQtODhlMy01NWEzM2QyZWQ0ZDYiLCJ1dGkiOiJGeWxCbk9nYkwwQy0zX0Z1Ym5VQUFBIiwidmVyIjoiMi4wIiwiZGF0ZU9mQmlydGgiOiIwMS8wMS8yMDAwIiwiY3VzdG9tUm9sZXMiOlsiV3JpdGVyIiwiRWRpdG9yIl0sImFwaVZlcnNpb24iOiIxLjAuMCIsImNvcnJlbGF0aW9uSWQiOiI4ZmM5M2FlYi01ZmMxLTQzOWQtYjM4OC1kYmY0YjM4ZGM3ODUifQ.rBu4Vw3ftWivyNXaDC7fB6HAB7TucGK1BUbSOt_ZW-ivsPLpHK7A4E0i8hu8Qs-zade6Fsp2deSaZNNLLNQCSDav7iMKZukNwQviWOG_Uvz31GVpkh1l26xTs3dlKS-6NjdwpkvccEg1VeIW-pyC_7RLAaCb1uzMoKFn7mA6meFCYBVnEZ3lRSw0_XtoKrcw5hJfvST4MOe7EJw2a2DH-fu1DDh-5FbCP4Y_nn6esre0I_Q0EwuF_4TYTESy_vqHwXZcTKZq34-5x4thRPGE1I_CBEJZkKXIWC6z788zEXSgnHvRfGEH52bRo_ZuPsftV1R1M9os0wPzgBOWwvMzOA"
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
        guard let accountResult = sut.makeUserAccountResult(tokenResult: tokenResult, context: context) else {
            XCTFail("Unexpected nil account")
            return
        }
        XCTAssertEqual(accountResult.account.username, username)
        XCTAssertEqual(accountResult.idToken, idToken)
        XCTAssertNotNil(accountResult.account.accountClaims)
        XCTAssertEqual(accountResult.account.accountClaims?.count, 21)
    }

    func test_makeUserAccount_withIncorrectIdToken_accountClaimsNotPresent() {
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
        guard let accountResult = sut.makeUserAccountResult(tokenResult: tokenResult, context: context) else {
            XCTFail("Unexpected nil account")
            return
        }
        XCTAssertEqual(accountResult.account.username, username)
        XCTAssertEqual(accountResult.idToken, idToken)
        XCTAssertNil(accountResult.account.accountClaims)
    }
}
