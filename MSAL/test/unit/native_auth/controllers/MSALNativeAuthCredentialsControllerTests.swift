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

final class MSALNativeAuthCredentialsControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthCredentialsController!
    private var requestProviderMock: MSALNativeAuthTokenRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factory: MSALNativeAuthResultFactoryMock!
    private var responseValidatorMock: MSALNativeAuthTokenResponseValidatorMock!
    private var tokenResult = MSIDTokenResult()
    private var tokenResponse = MSIDCIAMTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private var apiErrorStub: MSALNativeAuthTokenResponseError!

    override func setUpWithError() throws {
        requestProviderMock = .init()
        cacheAccessorMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        factory = .init()
        responseValidatorMock = .init()
        sut = .init(
            clientId: DEFAULT_TEST_CLIENT_ID,
            requestProvider: requestProviderMock,
            cacheAccessor: cacheAccessorMock,
            factory: factory,
            responseValidator: responseValidatorMock
        )
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        apiErrorStub = MSALNativeAuthTokenResponseError(
            error: .userNotFound,
            subError: nil,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            continuationToken: nil
        )

        try super.setUpWithError()
    }

    // MARK: get native user account tests

    func test_whenNoAccountPresent_shouldReturnNoUserAccountResult() {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let accountResult = sut.retrieveUserAccountResult(context: expectedContext)
        XCTAssertNil(accountResult)
    }

    func test_whenNoTokenPresent_shouldReturnNoUserAccountResult() {
        let account = MSALNativeAuthUserAccountResultStub.account
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens
        let userAccountResult = MSALNativeAuthUserAccountResult(
            account: account,
            authTokens: authTokens,
            configuration: MSALNativeAuthConfigStubs.configuration,
            cacheAccessor: MSALNativeAuthCacheAccessorMock()
        )
        factory.mockMakeUserAccountResult(userAccountResult)
        cacheAccessorMock.mockUserAccounts = [account]
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let accountResult = sut.retrieveUserAccountResult(context: expectedContext)
        XCTAssertNil(accountResult)
    }

    func test_whenAccountSet_shouldReturnUserAccountResult() async {
        let account = MSALNativeAuthUserAccountResultStub.account
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens

        let userAccountResult = MSALNativeAuthUserAccountResult(
            account: account,
            authTokens: authTokens,
            configuration: MSALNativeAuthConfigStubs.configuration,
            cacheAccessor: MSALNativeAuthCacheAccessorMock()
        )

        factory.mockMakeUserAccountResult(userAccountResult)
        cacheAccessorMock.mockUserAccounts = [account]
        cacheAccessorMock.mockAuthTokens = authTokens
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let accountResult = sut.retrieveUserAccountResult(context: expectedContext)
        XCTAssertEqual(accountResult?.account.username, account.username)
        XCTAssertEqual(accountResult?.idToken, authTokens.rawIdToken)
        XCTAssertTrue(NSDictionary(dictionary: accountResult?.account.accountClaims ?? [:]).isEqual(to: account.accountClaims ?? [:]))
    }

    private func checkTelemetryEventResult(id: MSALNativeAuthTelemetryApiId, isSuccessful: Bool) {
        XCTAssertEqual(receivedEvents.count, 1)

        guard let telemetryEventDict = receivedEvents.first else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(id.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event" )
        XCTAssertEqual(telemetryEventDict["correlation_id" ] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, isSuccessful ? "yes" : "no")
        XCTAssertEqual(telemetryEventDict["status"] as? String, isSuccessful ? "succeeded" : "failed")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
    }

    private func createApiErrorStub(message: String) -> MSALNativeAuthTokenResponseError {
        return MSALNativeAuthTokenResponseError(
            error: .userNotFound,
            subError: nil,
            errorDescription: message,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            continuationToken: nil
        )
    }
}
