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

final class MSALNativeAuthCredentialsControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthCredentialsController!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factory: MSALNativeAuthResultFactoryMock!
    private var tokenResponse = MSIDCIAMTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!

    override func setUpWithError() throws {
        cacheAccessorMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        factory = MSALNativeAuthResultFactoryMock()
        sut = .init(
            clientId: DEFAULT_TEST_CLIENT_ID,
            cacheAccessor: cacheAccessorMock,
            factory: factory
        )
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        try super.setUpWithError()
    }
    
    // MARK: get native user account tests

    func test_whenNoAccountPresent_shouldReturnNoAccounts() {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let accountResult = sut.retrieveUserAccountResult(context: expectedContext)
        XCTAssertNil(accountResult)
    }

    func test_whenNoTokenPresent_shouldReturnNoAccounts() {
        let account = MSALNativeAuthUserAccountResultStub.account
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens
        let userAccountResult = MSALNativeAuthUserAccountResult(account: account, authTokens: authTokens)
        factory.mockMakeUserAccountResult(userAccountResult)
        cacheAccessorMock.mockUserAccounts = [account]
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let accountResult = sut.retrieveUserAccountResult(context: expectedContext)
        XCTAssertNil(accountResult)
    }

    func test_whenAccountSet_shouldReturnAccount() async {
        let account = MSALNativeAuthUserAccountResultStub.account
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens
        let userAccountResult = MSALNativeAuthUserAccountResult(account: account, authTokens: authTokens)

        factory.mockMakeUserAccountResult(userAccountResult)
        cacheAccessorMock.mockUserAccounts = [account]
        cacheAccessorMock.mockAuthTokens = authTokens
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let accountResult = sut.retrieveUserAccountResult(context: expectedContext)
        XCTAssertEqual(accountResult?.username, account.username)
        XCTAssertEqual(accountResult?.idToken, authTokens.rawIdToken)
        XCTAssertEqual(accountResult?.scopes, authTokens.accessToken?.scopes.array as? [String])
        XCTAssertEqual(accountResult?.expiresOn, authTokens.accessToken?.expiresOn)
        XCTAssertTrue(NSDictionary(dictionary: accountResult?.accountClaims ?? [:]).isEqual(to: account.accountClaims ?? [:]))
    }
}
