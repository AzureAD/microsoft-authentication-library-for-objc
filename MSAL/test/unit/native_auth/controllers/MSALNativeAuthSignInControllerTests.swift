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

final class MSALNativeAuthSignInControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthSignInController!
    private var signInRequestProviderMock: MSALNativeAuthSignInRequestProviderMock!
    private var tokenRequestProviderMock: MSALNativeAuthTokenRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var signInResponseValidatorMock: MSALNativeAuthSignInResponseValidatorMock!
    private var tokenResponseValidatorMock: MSALNativeAuthTokenResponseValidatorMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var tokenResult = MSIDTokenResult()
    private var tokenResponse = MSIDCIAMTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private let defaultScopes = "openid profile offline_access"

    private var signInInitiateApiErrorStub: MSALNativeAuthSignInInitiateResponseError {
        .init(error: .invalidRequest, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
    }

    private var signInChallengeApiErrorStub: MSALNativeAuthSignInChallengeResponseError {
        .init(
            error: .expiredToken,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil
        )
    }

    private var signInTokenApiErrorStub: MSALNativeAuthTokenResponseError {
        .init(error: .expiredToken, subError: nil, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil)
    }

    override func setUpWithError() throws {
        signInRequestProviderMock = .init()
        tokenRequestProviderMock = .init()
        cacheAccessorMock = .init()
        signInResponseValidatorMock = .init()
        tokenResponseValidatorMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        
        sut = .init(
            clientId: DEFAULT_TEST_CLIENT_ID,
            signInRequestProvider: signInRequestProviderMock,
            tokenRequestProvider: tokenRequestProviderMock,
            cacheAccessor: cacheAccessorMock,
            factory: MSALNativeAuthResultFactoryMock(),
            signInResponseValidator: signInResponseValidatorMock,
            tokenResponseValidator: tokenResponseValidatorMock
        )
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        tokenResult.rawIdToken = "idToken"

        try super.setUpWithError()
    }
    
    // MARK: sign in with username and password tests

    func test_whenCreateRequestFails_shouldReturnError() async throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingInitError = ErrorMock.error

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError, message: "SignIn Initiate: Cannot create Initiate request object", correlationId: defaultUUID))

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenUserSpecifiesScope_defaultScopesShouldBeIncluded() async throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        let continuationToken = "continuationToken"

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError, correlationId: defaultUUID))

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "scope2"]))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenUserSpecifiesScopes_NoDuplicatedScopeShouldBeSent() async throws {
        let expectation = expectation(description: "SignInController")
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScopes = "scope1 openid profile offline_access"
        let continuationToken = "continuationToken"

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)
        tokenRequestProviderMock.throwingTokenError = ErrorMock.error

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError, correlationId: defaultUUID))

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "openid", "profile"]))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_successfulResponseAndValidation_shouldCompleteSignIn() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"

        let expectation = expectation(description: "SignInController")

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedUsername = expectedUsername
        tokenRequestProviderMock.expectedContext = expectedContext

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInCompleted(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: true)
    }

    func test_successfulResponseAndUnsuccessfulValidation_shouldReturnError() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"

        let expectation = expectation(description: "SignInController")

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedUsername = expectedUsername
        tokenRequestProviderMock.expectedContext = expectedContext

        let delegateError = SignInStartError(type: .generalError, correlationId: defaultUUID)
        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = nil
        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_errorResponse_shouldReturnError() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "invalid token"

        let expectation = expectation(description: "SignInController")

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .error(.invalidToken(signInChallengeApiErrorStub))

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedUsername = expectedUsername
        tokenRequestProviderMock.expectedContext = expectedContext

        let delegateError = SignInStartError(type: .generalError, correlationId: defaultUUID)
        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }
    
    func test_whenErrorIsReturnedFromValidator_itIsCorrectlyTranslatedToDelegateError() async  {
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .generalError(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .expiredToken(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .authorizationPending(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .slowDown(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidRequest(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Invalid Client ID", correlationId: defaultUUID), validatorError: .unauthorizedClient(createSignInTokenApiError(message: "Invalid Client ID")))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Unexpected response body received", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Unexpected response body received")))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Unsupported challenge type", correlationId: defaultUUID), validatorError: .unsupportedChallengeType(createSignInTokenApiError(message: "Unsupported challenge type")))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Invalid scope", correlationId: defaultUUID), validatorError: .invalidScope(createSignInTokenApiError(message: "Invalid scope")))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .userNotFound, correlationId: defaultUUID), validatorError: .userNotFound(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .invalidCredentials, correlationId: defaultUUID), validatorError: .invalidPassword(signInTokenApiErrorStub))
        await checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Error message", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Error message")))
    }
    
    func test_whenCredentialsAreRequired_browserRequiredErrorIsReturned() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedCredentialToken = continuationToken

        let expectation = expectation(description: "SignInController")

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: .init(type: .browserRequired, message: MSALNativeAuthErrorMessage.unsupportedMFA, correlationId: defaultUUID))

        tokenResponseValidatorMock.tokenValidatedResponse = .error(.strongAuthRequired(.init(error: .unauthorizedClient, subError: nil, errorDescription: MSALNativeAuthErrorMessage.unsupportedMFA, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil)))

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenSignInUsingPassword_apiReturnsChallengeTypeOOB_codeRequiredShouldBeCalled() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"

        let expectation = expectation(description: "SignInController")

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation)
        helper.expectedSentTo = expectedSentTo
        helper.expectedChannelTargetType = expectedChannelTargetType
        helper.expectedCodeLength = expectedCodeLength

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.success(()))

        helper.onSignInCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: true)
    }

    func test_whenSignInUsingPassword_apiReturnsChallengeTypeOOB_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"

        let expectation = expectation(description: "SignInController")

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation)
        helper.expectedSentTo = expectedSentTo
        helper.expectedChannelTargetType = expectedChannelTargetType
        helper.expectedCodeLength = expectedCodeLength

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: defaultUUID)))

        helper.onSignInCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }
    
    // MARK: sign in with username and code
    
    func test_whenSignInWithCodeStartWithValidInfo_codeRequiredShouldBeCalled() async {
        let expectedUsername = "username"
        let sentTo = "sentTo"
        let channelTargetType = MSALNativeAuthChannelType.email
        let codeLength = 4
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.success(()))

        helper.onSignInCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: true)
    }

    func test_afterSignInWithCodeSubmitCode_signInShouldCompleteSuccessfully() {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: defaultScopes, password: nil, oobCode: "code", includeChallengeType: false, refreshToken: nil)

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        cacheAccessorMock.mockUserAccounts = [MSALNativeAuthUserAccountResultStub.account]
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let state = SignInCodeRequiredState(scopes: ["openid","profile","offline_access"], controller: sut, inputValidator: MSALNativeAuthInputValidator(), continuationToken: continuationToken, correlationId: defaultUUID)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedUserAccountResult: userAccountResult))

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: true)
    }

    func test_afterSignInWithCodeSubmitCode_whenTokenCacheIsNotValid_it_shouldReturnCorrectError() {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: defaultScopes, password: nil, oobCode: "code", includeChallengeType: false, refreshToken: nil)

        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        cacheAccessorMock.expectedMSIDTokenResult = nil

        let state = SignInCodeRequiredState(scopes: ["openid","profile","offline_access"], controller: sut, inputValidator: MSALNativeAuthInputValidator(), continuationToken: continuationToken, correlationId: defaultUUID)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedError: VerifyCodeError(type: .generalError, correlationId: defaultUUID)))

        wait(for: [expectation], timeout: 1)

        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeStartAndInitiateRequestCreationFail_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingInitError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError, message: "SignIn Initiate: Cannot create Initiate request object", correlationId: defaultUUID))

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeStartAndInitiateReturnError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .browserRequired, correlationId: defaultUUID), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .unauthorizedClient(signInInitiateApiErrorStub))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .userNotFound, correlationId: defaultUUID), validatorError: .userNotFound(signInInitiateApiErrorStub))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .unsupportedChallengeType(signInInitiateApiErrorStub))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidRequest(createSignInInitiateApiError(correlationId: defaultUUID)))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, message: "Unexpected response body received", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Unexpected response body received")))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, message: "Error message", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Error message")))
    }
    
    func test_whenSignInWithCodeChallengeRequestCreationFail_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: "continuationToken")

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError, correlationId: defaultUUID))

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeChallengeReturnsError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .browserRequired, correlationId: defaultUUID), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .expiredToken(signInChallengeApiErrorStub))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidToken(signInChallengeApiErrorStub))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidRequest(createSignInChallengeApiError(correlationId: defaultUUID)))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .unauthorizedClient(signInChallengeApiErrorStub))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, message: "Unexpected response body received", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Unexpected response body received")))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .userNotFound, correlationId: defaultUUID), validatorError: .userNotFound(signInChallengeApiErrorStub))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, correlationId: defaultUUID), validatorError: .unsupportedChallengeType(signInChallengeApiErrorStub))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, message: "Error message", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Error message")))
    }
    
    func test_whenSignInWithCodePasswordIsRequired_newStateIsPropagatedToUser() async {
        let expectedUsername = "username"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: expectedCredentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: expectedCredentialToken)
        
        let helper = SignInCodeStartWithPasswordRequiredTestsValidatorHelper(expectation: expectation)

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.success(()))

        helper.onSignInPasswordRequired(result.result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: true)
        XCTAssertEqual(helper.passwordRequiredState?.continuationToken, expectedCredentialToken)
    }

    func test_whenSignInWithCodePasswordIsRequired_newStateIsPropagatedToUser_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        let expectedUsername = "username"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: expectedCredentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: expectedCredentialToken)

        let helper = SignInCodeStartWithPasswordRequiredTestsValidatorHelper(expectation: expectation)

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: defaultUUID)))

        helper.onSignInPasswordRequired(result.result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        XCTAssertEqual(helper.passwordRequiredState?.continuationToken, expectedCredentialToken)
    }
    
    func test_whenSignInWithCodeSubmitPassword_signInIsCompletedSuccessfully() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, continuationToken: expectedCredentialToken, grantType: MSALNativeAuthGrantType.password, scope: "", password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)

        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedUserAccountResult: MSALNativeAuthUserAccountResultStub.result)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse
        cacheAccessorMock.mockUserAccounts = [MSALNativeAuthUserAccountResultStub.account]
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate)

        await fulfillment(of: [exp], timeout: 1)

        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: true)
    }

    func test_whenSignInWithCodeSubmitPassword_whenTokenCacheIsNotValid_it_shouldReturnCorrectError() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, continuationToken: expectedCredentialToken, grantType: MSALNativeAuthGrantType.password, scope: "", password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)

        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID))
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse
        cacheAccessorMock.expectedMSIDTokenResult = nil

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate)

        await fulfillment(of: [exp], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeSubmitPasswordTokenRequestCreationFail_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.throwingTokenError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
        signInRequestProviderMock.expectedContext = expectedContext
        
        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID))

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertNotNil(mockDelegate.newPasswordRequiredState)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeSubmitPasswordTokenAPIReturnError_correctErrorShouldBeReturned() async {
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .generalError(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .expiredToken(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .unauthorizedClient(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidRequest(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, message: "Unexpected response body received", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Unexpected response body received")))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, message: "User does not exist", correlationId: defaultUUID), validatorError: .userNotFound(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidOOBCode(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .unsupportedChallengeType(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .browserRequired, correlationId: defaultUUID), validatorError: .strongAuthRequired(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .invalidScope(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .authorizationPending(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, correlationId: defaultUUID), validatorError: .slowDown(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .invalidPassword, correlationId: defaultUUID), validatorError: .invalidPassword(signInTokenApiErrorStub))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError, message: "Error message", correlationId: defaultUUID), validatorError: .unexpectedError(.init(errorDescription: "Error message")))
    }
    
    func test_signInWithCodeSubmitCodeTokenRequestFailCreation_errorShouldBeReturned() {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.throwingTokenError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)

        let state = SignInCodeRequiredState(scopes: [], controller: sut, continuationToken: continuationToken, correlationId: defaultUUID)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedError: VerifyCodeError(type: .generalError, correlationId: defaultUUID)))

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
    }
    
    func test_signInWithCodeSubmitCodeReturnError_correctResultShouldReturned() {
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .generalError(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .expiredToken(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .unauthorizedClient(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidRequest(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .unexpectedError(.init(errorDescription: "Unexpected response body received")))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .userNotFound(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .invalidCode, validatorError: .invalidOOBCode(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .unsupportedChallengeType(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .browserRequired, validatorError: .strongAuthRequired(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidScope(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .authorizationPending(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .slowDown(signInTokenApiErrorStub))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidPassword(signInTokenApiErrorStub))
    }
        
    func test_signInWithCodeResendCode_shouldSendNewCode() async {
        let expectedUsername = "username"
        let sentTo = "sentTo"
        let channelTargetType = MSALNativeAuthChannelType.email
        let codeLength = 4
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        let result = await sut.resendCode(continuationToken: continuationToken, context: expectedContext, scopes: [])
        result.telemetryUpdate?(.success(()))

        helper.onSignInResendCodeCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: true)
    }
    
    func test_signInWithCodeResendCodeChallengeCreationFail_errorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation)

        let result = await sut.resendCode(continuationToken: "continuationToken", context: expectedContext, scopes: [])

        helper.onSignInResendCodeError(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNotNil(helper.newSignInCodeRequiredState)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: false)
    }
    
    func test_signInWithCodeResendCodePasswordRequired_shouldReturnAnError() async {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation)

        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)

        let result = await sut.resendCode(continuationToken: continuationToken, context: expectedContext, scopes: [])

        helper.onSignInResendCodeError(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNil(helper.newSignInCodeRequiredState)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: false)
    }
    
    func test_signInWithCodeResendCodeChallengeReturnError_shouldReturnAnError() async {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation)

        signInResponseValidatorMock.challengeValidatedResponse = .error(.userNotFound(signInChallengeApiErrorStub))

        let result = await sut.resendCode(continuationToken: continuationToken, context: expectedContext, scopes: [])

        helper.onSignInResendCodeError(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNotNil(helper.newSignInCodeRequiredState)
        XCTAssertEqual(helper.newSignInCodeRequiredState?.continuationToken, continuationToken)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: false)
    }
    
    // MARK: signIn using ContinuationToken
    
    func test_whenSignInWithContinuationToken_signInIsCompletedSuccessfully() {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: "", continuationToken: continuationToken, grantType: .continuationToken, scope: defaultScopes, password: nil, oobCode: nil, includeChallengeType: false, refreshToken: nil)

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result
        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        let state = SignInAfterSignUpState(controller: sut, username: "", continuationToken: continuationToken, correlationId: defaultUUID)
        state.signIn(delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: true)
    }
    
    func test_whenSignInWithContinuationTokenTokenRequestCreationFail_errorShouldBeReturned() {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.throwingTokenError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
        signInRequestProviderMock.expectedContext = expectedContext
        
        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: exp, expectedError: SignInAfterSignUpError(correlationId: defaultUUID))

        let state = SignInAfterSignUpState(controller: sut, username: "", continuationToken: continuationToken, correlationId: defaultUUID)
        state.signIn(delegate: mockDelegate)
        
        wait(for: [exp], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }
    
    func test_whenSignInWithContinuationTokenTokenReturnError_shouldReturnAnError() {
        let continuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext

        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedError: SignInAfterSignUpError(message: MSALNativeAuthErrorMessage.generalError, correlationId: defaultUUID))

        tokenResponseValidatorMock.tokenValidatedResponse = .error(.unauthorizedClient(signInTokenApiErrorStub))

        let state = SignInAfterSignUpState(controller: sut, username: "", continuationToken: continuationToken, correlationId: defaultUUID)
        state.signIn(delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }
    
    func test_whenSignInWithContinuationTokenHaveTokenNil_shouldReturnAnError() {
        let expectation = expectation(description: "SignInController")

        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedError: SignInAfterSignUpError(message: "Sign In is not available at this point, please use the standalone sign in methods", correlationId: defaultUUID))

        let state = SignInAfterSignUpState(controller: sut, username: "username", continuationToken: nil, correlationId: defaultUUID)
        state.signIn(delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }

    
    // MARK: private methods

    private func checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: VerifyCodeError.ErrorType, validatorError: MSALNativeAuthTokenValidatedErrorType) {
        let expectedCredentialToken = "continuationToken"
        let expectedOOBCode = "code"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: expectedCredentialToken, grantType: MSALNativeAuthGrantType.oobCode, scope: "", password: nil, oobCode: expectedOOBCode, includeChallengeType: true, refreshToken: nil)
        let mockDelegate = SignInVerifyCodeDelegateSpy(expectation: exp, expectedError: VerifyCodeError(type: delegateError, correlationId: defaultUUID))
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)
        
        let state = SignInCodeRequiredState(scopes: [], controller: sut, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitCode(code: expectedOOBCode, delegate: mockDelegate)

        wait(for: [exp], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError, validatorError: MSALNativeAuthTokenValidatedErrorType) async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, continuationToken: expectedCredentialToken, grantType: MSALNativeAuthGrantType.password, scope: "", password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)
        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: publicError)
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError, validatorError: MSALNativeAuthSignInChallengeValidatedErrorType) async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.mockInitiateRequestFunc((MSALNativeAuthHTTPRequestMock.prepareMockRequest()))
        signInRequestProviderMock.mockChallengeRequestFunc((MSALNativeAuthHTTPRequestMock.prepareMockRequest()))
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: "continuationToken")
        signInResponseValidatorMock.challengeValidatedResponse = .error(validatorError)
        
        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError, validatorError: MSALNativeAuthSignInInitiateValidatedErrorType) async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.initiateValidatedResponse = .error(validatorError)

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)

        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkDelegateErrorWithValidatorError(delegateError: SignInStartError, validatorError: MSALNativeAuthTokenValidatedErrorType) async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"

        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: continuationToken)

        signInRequestProviderMock.mockInitiateRequestFunc((MSALNativeAuthHTTPRequestMock.prepareMockRequest()))
        signInRequestProviderMock.mockChallengeRequestFunc((MSALNativeAuthHTTPRequestMock.prepareMockRequest()))
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = continuationToken
        signInRequestProviderMock.expectedContext = expectedContext

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)
        
        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
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


    private func createSignInTokenApiError(message: String) -> MSALNativeAuthTokenResponseError {
        .init(error: .expiredToken, subError: nil, errorDescription: message, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil)
    }

    private func createSignInInitiateApiError(correlationId: UUID) -> MSALNativeAuthSignInInitiateResponseError {
        var error = MSALNativeAuthSignInInitiateResponseError()
        error.correlationId = correlationId
        return error
    }

    private func createSignInChallengeApiError(correlationId: UUID) -> MSALNativeAuthSignInChallengeResponseError {
        var error = MSALNativeAuthSignInChallengeResponseError()
        error.correlationId = correlationId
        return error
    }
}
