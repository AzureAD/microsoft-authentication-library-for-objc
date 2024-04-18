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
        XCTAssertEqual(accountResult?.account.username, account.username)
        XCTAssertEqual(accountResult?.idToken, authTokens.rawIdToken)
        XCTAssertTrue(NSDictionary(dictionary: accountResult?.account.accountClaims ?? [:]).isEqual(to: account.accountClaims ?? [:]))
    }

    func test_whenCreateRequestFails_shouldReturnError() async throws {
        let expectation = expectation(description: "CredentialsController")

        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens

        requestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: nil, grantType: MSALNativeAuthGrantType.refreshToken, scope: "" , password: nil, oobCode: nil, includeChallengeType: true, refreshToken: "refreshToken")
        requestProviderMock.throwingRefreshTokenError = ErrorMock.error

        let helper = CredentialsTestValidatorHelper(expectation: expectation, expectedError: RetrieveAccessTokenError(type: .generalError, correlationId: defaultUUID))

        let result = await sut.refreshToken(context: expectedContext, authTokens: authTokens)
        helper.onAccessTokenRetrieveError(result)

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

        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        requestProviderMock.mockRequestRefreshTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let expectedAccessToken = "accessToken"
        let helper = CredentialsTestValidatorHelper(expectation: expectation, expectedResult: MSALNativeAuthTokenResult(authTokens: authTokens))
        helper.expectedAccessToken = authTokens.accessToken.accessToken
        helper.expectedExpiresOn = authTokens.accessToken.expiresOn
        helper.expectedScopes = authTokens.accessToken.scopes.array as? [String] ?? []

        factory.mockMakeUserAccountResult(userAccountResult)
        tokenResult.accessToken = MSIDAccessToken()
        tokenResult.accessToken.accessToken = expectedAccessToken
        responseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        cacheAccessorMock.mockUserAccounts = [account]
        cacheAccessorMock.mockAuthTokens = authTokens
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        let result = await sut.refreshToken(context: expectedContext, authTokens: authTokens)
        helper.onAccessTokenRetrieveCompleted(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(expectedAccessToken, authTokens.accessToken.accessToken)
    }

    func test_whenErrorIsReturnedFromValidator_itIsCorrectlyTranslatedToDelegateError() async  {
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, correlationId: defaultUUID), validatorError: .generalError(apiErrorStub))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, correlationId: defaultUUID), validatorError: .expiredToken(apiErrorStub))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, correlationId: defaultUUID), validatorError: .authorizationPending(apiErrorStub))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, correlationId: defaultUUID), validatorError: .slowDown(apiErrorStub))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidRequest(apiErrorStub))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, message: "Invalid Client ID", correlationId: defaultUUID), validatorError: .unauthorizedClient(createApiErrorStub(message: "Invalid Client ID")))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, message: "Unsupported challenge type", correlationId: defaultUUID), validatorError: .unsupportedChallengeType(createApiErrorStub(message: "Unsupported challenge type")))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .generalError, message: "Invalid scope", correlationId: defaultUUID), validatorError: .invalidScope(createApiErrorStub(message: "Invalid scope")))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .refreshTokenExpired, correlationId: defaultUUID), validatorError: .expiredRefreshToken(apiErrorStub))
        await checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError(type: .browserRequired, message: "MFA currently not supported. Use the browser instead", correlationId: defaultUUID), validatorError: .strongAuthRequired(createApiErrorStub(message: "MFA currently not supported. Use the browser instead")))
    }

    private func checkPublicErrorWithValidatorError(publicError: RetrieveAccessTokenError, validatorError: MSALNativeAuthTokenValidatedErrorType) async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authTokens = MSALNativeAuthUserAccountResultStub.authTokens

        let expectation = expectation(description: "CredentialsController")

        requestProviderMock.mockRequestRefreshTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let helper = CredentialsTestValidatorHelper(expectation: expectation, expectedError: publicError)
        responseValidatorMock.tokenValidatedResponse = .error(validatorError)

        let result = await sut.refreshToken(context: expectedContext, authTokens: authTokens)
        helper.onAccessTokenRetrieveError(result)

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
