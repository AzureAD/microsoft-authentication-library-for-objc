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
    private var requestProviderMock: MSALNativeAuthTokenRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factory: MSALNativeAuthResultFactoryMock!
    private var responseValidatorMock: MSALNativeAuthTokenResponseValidatorMock!
    private var tokenResult = MSIDTokenResult()
    private var tokenResponse = MSIDCIAMTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!

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

    func test_whenAccountSet_shouldReturnAccount() async {
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
        XCTAssertEqual(accountResult?.username, account.username)
        XCTAssertEqual(accountResult?.idToken, authTokens.rawIdToken)
        XCTAssertEqual(accountResult?.scopes, authTokens.accessToken?.scopes.array as? [String])
        XCTAssertEqual(accountResult?.expiresOn, authTokens.accessToken?.expiresOn)
        XCTAssertTrue(NSDictionary(dictionary: accountResult?.accountClaims ?? [:]).isEqual(to: account.accountClaims ?? [:]))
    }

    func test_whenCreateRequestFails_shouldReturnError() async throws {
        let expectation = expectation(description: "CredentialsController")

        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens

        requestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.refreshToken, scope: "" , password: nil, oobCode: nil, addNCAFlag: true, includeChallengeType: true, refreshToken: "refreshToken")
        requestProviderMock.throwingTokenError = ErrorMock.error

        let mockDelegate = CredentialsDelegateSpy(expectation: expectation, expectedError: RetrieveAccessTokenError(type: .generalError))

        await sut.refreshToken(context: expectedContext, authTokens: authTokens, delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdRefreshToken, isSuccessful: false)
    }

    func test_whenAccountSet_shouldRefreshToken() async {
        let expectation = expectation(description: "CredentialsController")

        let account = MSALNativeAuthUserAccountResultStub.account
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens
        let userAccountResult = MSALNativeAuthUserAccountResult(account: account,
                                                                authTokens: authTokens,
                                                                configuration: MSALNativeAuthConfigStubs.configuration, cacheAccessor: MSALNativeAuthCacheAccessorMock())

        let request = MSIDHttpRequest()
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        requestProviderMock.result = request

        let expectedAccessToken = "accessToken"
        let mockDelegate = CredentialsDelegateSpy(expectation: expectation, expectedAccessToken: expectedAccessToken)

        factory.mockMakeUserAccountResult(userAccountResult)
        tokenResult.accessToken = MSIDAccessToken()
        tokenResult.accessToken.accessToken = expectedAccessToken
        responseValidatorMock.tokenValidatedResponse = .success(userAccountResult, tokenResult, tokenResponse)
        cacheAccessorMock.mockUserAccounts = [account]
        cacheAccessorMock.mockAuthTokens = authTokens
        await sut.refreshToken(context: expectedContext, authTokens: authTokens, delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(expectedAccessToken, authTokens.accessToken?.accessToken)
    }

    func test_whenErrorIsReturnedFromValidator_itIsCorrectlyTranslatedToDelegateError() async  {
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError), validatorError: .generalError)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError), validatorError: .expiredToken)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError), validatorError: .authorizationPending)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError), validatorError: .slowDown)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError), validatorError: .invalidRequest)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError), validatorError: .invalidServerResponse)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError, message: "Invalid Client ID"), validatorError: .invalidClient)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError, message: "Unsupported challenge type"), validatorError: .unsupportedChallengeType)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .generalError, message: "Invalid scope"), validatorError: .invalidScope)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .refreshTokenExpired), validatorError: .expiredRefreshToken)
        await checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError(type: .browserRequired, message: "MFA currently not supported. Use the browser instead"), validatorError: .strongAuthRequired)
    }

    private func checkDelegateErrorWithValidatorError(delegateError: RetrieveAccessTokenError, validatorError: MSALNativeAuthTokenValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "CredentialsController")

        requestProviderMock.result = request

        let mockDelegate = CredentialsDelegateSpy(expectation: expectation, expectedError: delegateError)
        responseValidatorMock.tokenValidatedResponse = .error(validatorError)


        await sut.refreshToken(context: expectedContext, authTokens: authTokens, delegate: mockDelegate)

        checkTelemetryEventResult(id: .telemetryApiIdRefreshToken, isSuccessful: false)
        receivedEvents.removeAll()
        await fulfillment(of: [expectation], timeout: 1)
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
}
