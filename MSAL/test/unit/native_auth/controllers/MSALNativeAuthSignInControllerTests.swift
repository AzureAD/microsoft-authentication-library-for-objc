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

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenUserSpecifiesScope_defaultScopesShouldBeIncluded() async throws {
        let expectation = expectation(description: "SignInController")

        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        let credentialToken = "credentialToken"

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "scope2"]))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenUserSpecifiesScopes_NoDuplicatedScopeShouldBeSent() async throws {
        let expectation = expectation(description: "SignInController")
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScopes = "scope1 openid profile offline_access"
        let credentialToken = "credentialToken"

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)
        tokenRequestProviderMock.throwingTokenError = ErrorMock.error

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "openid", "profile"]))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_successfulResponseAndValidation_shouldCompleteSignIn() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"

        let expectation = expectation(description: "SignInController")

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedUsername = expectedUsername
        tokenRequestProviderMock.expectedContext = expectedContext

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInCompleted(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: true)
    }

    func test_successfulResponseAndUnsuccessfulValidation_shouldReturnError() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"

        let expectation = expectation(description: "SignInController")

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedUsername = expectedUsername
        tokenRequestProviderMock.expectedContext = expectedContext

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = nil
        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_errorResponse_shouldReturnError() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "invalid token"

        let expectation = expectation(description: "SignInController")

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .error(.invalidToken(message: nil))

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedUsername = expectedUsername
        tokenRequestProviderMock.expectedContext = expectedContext

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }
    
    func test_whenErrorIsReturnedFromValidator_itIsCorrectlyTranslatedToDelegateError() async  {
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .generalError)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .expiredToken(message: nil))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .authorizationPending(message: nil))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .slowDown(message: nil))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .invalidRequest(message: nil))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Invalid server response"), validatorError: .invalidServerResponse)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Invalid Client ID"), validatorError: .invalidClient(message: "Invalid Client ID"))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Unsupported challenge type"), validatorError: .unsupportedChallengeType(message: "Unsupported challenge type"))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Invalid scope"), validatorError: .invalidScope(message: "Invalid scope"))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .userNotFound), validatorError: .userNotFound(message: nil))
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .invalidPassword), validatorError: .invalidPassword(message: nil))
    }
    
    func test_whenCredentialsAreRequired_browserRequiredErrorIsReturned() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedCredentialToken = credentialToken

        let expectation = expectation(description: "SignInController")

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: .init(type: .browserRequired, message: MSALNativeAuthErrorMessage.unsupportedMFA))

        tokenResponseValidatorMock.tokenValidatedResponse = .error(.strongAuthRequired(message: "MFA currently not supported. Use the browser instead"))

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

        helper.onSignInPasswordError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenSignInUsingPassword_apiReturnsChallengeTypeOOB_codeRequiredShouldBeCalled() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"

        let expectation = expectation(description: "SignInController")

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation)
        helper.expectedSentTo = expectedSentTo
        helper.expectedChannelTargetType = expectedChannelTargetType
        helper.expectedCodeLength = expectedCodeLength

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.success(()))

        helper.onSignInCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: true)
    }

    func test_whenSignInUsingPassword_apiReturnsChallengeTypeOOB__butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"

        let expectation = expectation(description: "SignInController")

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation)
        helper.expectedSentTo = expectedSentTo
        helper.expectedChannelTargetType = expectedChannelTargetType
        helper.expectedCodeLength = expectedCodeLength

        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.failure(.init(message: "error")))

        helper.onSignInCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }
    
    // MARK: sign in with username and code
    
    func test_whenSignInWithCodeStartWithValidInfo_codeRequiredShouldBeCalled() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let sentTo = "sentTo"
        let channelTargetType = MSALNativeAuthChannelType.email
        let codeLength = 4
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))

        helper.onSignInCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: true)
    }

    func test_afterSignInWithCodeSubmitCode_signInShouldCompleteSuccessfully() {
        let request = MSIDHttpRequest()
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.oobCode, scope: defaultScopes, password: nil, oobCode: "code", includeChallengeType: false, refreshToken: nil)

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        cacheAccessorMock.mockUserAccounts = [MSALNativeAuthUserAccountResultStub.account]
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let state = SignInCodeRequiredState(scopes: ["openid","profile","offline_access"], controller: sut, inputValidator: MSALNativeAuthInputValidator(), flowToken: credentialToken)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedUserAccountResult: userAccountResult), correlationId: defaultUUID)

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: true)
    }

    func test_afterSignInWithCodeSubmitCode_whenTokenCacheIsNotValid_it_shouldReturnCorrectError() {
        let request = MSIDHttpRequest()
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.oobCode, scope: defaultScopes, password: nil, oobCode: "code", includeChallengeType: false, refreshToken: nil)

        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        cacheAccessorMock.expectedMSIDTokenResult = nil

        let state = SignInCodeRequiredState(scopes: ["openid","profile","offline_access"], controller: sut, inputValidator: MSALNativeAuthInputValidator(), flowToken: credentialToken)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedError: VerifyCodeError(type: .generalError)), correlationId: defaultUUID)

        wait(for: [expectation], timeout: 1)

        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeStartAndInitiateRequestCreationFail_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingInitError = MSALNativeAuthError()

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError))

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeStartAndInitiateReturnError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .browserRequired), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, message: nil), validatorError: .invalidClient(message: nil))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .userNotFound), validatorError: .userNotFound(message: nil))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .unsupportedChallengeType(message: nil))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidRequest(message: nil))
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidServerResponse)
    }
    
    func test_whenSignInWithCodeChallengeRequestCreationFail_errorShouldBeReturned() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError()
        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: "credentialToken")
        
        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: SignInStartError(type: .generalError))

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeChallengeReturnsError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .browserRequired), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .expiredToken(message: nil))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidToken(message: nil))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidRequest(message: nil))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidServerResponse)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, message: nil), validatorError: .invalidClient(message: nil))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .userNotFound), validatorError: .userNotFound(message: nil))
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, message: nil), validatorError: .unsupportedChallengeType(message: nil))
    }
    
    func test_whenSignInWithCodePasswordIsRequired_newStateIsPropagatedToUser() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedCredentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: expectedCredentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: expectedCredentialToken)
        
        let helper = SignInCodeStartWithPasswordRequiredTestsValidatorHelper(expectation: expectation)

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.success(()))

        helper.onSignInPasswordRequired(result.result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: true)
        XCTAssertEqual(helper.passwordRequiredState?.flowToken, expectedCredentialToken)
    }

    func test_whenSignInWithCodePasswordIsRequired_newStateIsPropagatedToUser_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedCredentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: expectedCredentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: expectedCredentialToken)

        let helper = SignInCodeStartWithPasswordRequiredTestsValidatorHelper(expectation: expectation)

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))
        result.telemetryUpdate?(.failure(.init(message: "error")))

        helper.onSignInPasswordRequired(result.result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        XCTAssertEqual(helper.passwordRequiredState?.flowToken, expectedCredentialToken)
    }
    
    func test_whenSignInWithCodeSubmitPassword_signInIsCompletedSuccessfully() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: expectedCredentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: "", password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)

        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedUserAccountResult: MSALNativeAuthUserAccountResultStub.result)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse
        cacheAccessorMock.mockUserAccounts = [MSALNativeAuthUserAccountResultStub.account]
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, flowToken: expectedCredentialToken)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate, correlationId: defaultUUID)

        await fulfillment(of: [exp], timeout: 1)

        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: true)
    }

    func test_whenSignInWithCodeSubmitPassword_whenTokenCacheIsNotValid_it_shouldReturnCorrectError() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let exp = expectation(description: "SignInController")

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: expectedCredentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: "", password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)

        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: PasswordRequiredError(type: .generalError))
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse
        cacheAccessorMock.expectedMSIDTokenResult = nil

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, flowToken: expectedCredentialToken)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate, correlationId: defaultUUID)

        await fulfillment(of: [exp], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeSubmitPasswordTokenRequestCreationFail_errorShouldBeReturned() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.throwingTokenError = MSALNativeAuthError()
        signInRequestProviderMock.expectedContext = expectedContext
        
        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: PasswordRequiredError(type: .generalError))

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, flowToken: expectedCredentialToken)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate, correlationId: defaultUUID)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertNotNil(mockDelegate.newPasswordRequiredState)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeSubmitPasswordTokenAPIReturnError_correctErrorShouldBeReturned() async {
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .generalError)
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .expiredToken(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .invalidClient(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .invalidRequest(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .invalidServerResponse)
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .userNotFound(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .invalidOOBCode(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .unsupportedChallengeType(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .browserRequired), validatorError: .strongAuthRequired(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .invalidScope(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .authorizationPending(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .generalError), validatorError: .slowDown(message: nil))
        await checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError(type: .invalidPassword), validatorError: .invalidPassword(message: nil))
    }
    
    func test_signInWithCodeSubmitCodeTokenRequestFailCreation_errorShouldBeReturned() {
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.throwingTokenError = MSALNativeAuthError()

        let state = SignInCodeRequiredState(scopes: [], controller: sut, flowToken: credentialToken)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedError: VerifyCodeError(type: .generalError)), correlationId: defaultUUID)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
    }
    
    func test_signInWithCodeSubmitCodeReturnError_correctResultShouldReturned() {
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .generalError)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .expiredToken(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidClient(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidRequest(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidServerResponse)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .userNotFound(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .invalidCode, validatorError: .invalidOOBCode(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .unsupportedChallengeType(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .browserRequired, validatorError: .strongAuthRequired(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidScope(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .authorizationPending(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .slowDown(message: nil))
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidPassword(message: nil))
    }
        
    func test_signInWithCodeResendCode_shouldSendNewCode() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let sentTo = "sentTo"
        let channelTargetType = MSALNativeAuthChannelType.email
        let codeLength = 4
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        let result = await sut.resendCode(credentialToken: credentialToken, context: expectedContext, scopes: [])

        helper.onSignInResendCodeCodeRequired(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: true)
    }
    
    func test_signInWithCodeResendCodeChallengeCreationFail_errorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError()

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation)

        let result = await sut.resendCode(credentialToken: "credentialToken", context: expectedContext, scopes: [])

        helper.onSignInResendCodeError(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNotNil(helper.newSignInCodeRequiredState)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: false)
    }
    
    func test_signInWithCodeResendCodePasswordRequired_shouldReturnAnError() async {
        let request = MSIDHttpRequest()
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation)

        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        let result = await sut.resendCode(credentialToken: credentialToken, context: expectedContext, scopes: [])

        helper.onSignInResendCodeError(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNil(helper.newSignInCodeRequiredState)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: false)
    }
    
    func test_signInWithCodeResendCodeChallengeReturnError_shouldReturnAnError() async {
        let request = MSIDHttpRequest()
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedContext = expectedContext

        let helper = SignInResendCodeTestsValidatorHelper(expectation: expectation)

        signInResponseValidatorMock.challengeValidatedResponse = .error(.userNotFound(message: nil))

        let result = await sut.resendCode(credentialToken: credentialToken, context: expectedContext, scopes: [])

        helper.onSignInResendCodeError(result)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNotNil(helper.newSignInCodeRequiredState)
        XCTAssertEqual(helper.newSignInCodeRequiredState?.flowToken, credentialToken)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: false)
    }
    
    // MARK: signIn using SLT
    
    func test_whenSignInWithSLT_signInIsCompletedSuccessfully() {
        let request = MSIDHttpRequest()
        let slt = "signInSLT"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        let expectation = expectation(description: "SignInController")
        
        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: "", credentialToken: nil, signInSLT: slt, grantType: .slt, scope: defaultScopes, password: nil, oobCode: nil, includeChallengeType: false, refreshToken: nil)

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result
        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        let state = SignInAfterSignUpState(controller: sut, username: "", slt: slt)
        state.signIn(correlationId: defaultUUID, delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: true)
    }
    
    func test_whenSignInWithSLTTokenRequestCreationFail_errorShouldBeReturned() {
        let request = MSIDHttpRequest()
        let slt = "signInSLT"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.throwingTokenError = MSALNativeAuthError()
        signInRequestProviderMock.expectedContext = expectedContext
        
        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: exp, expectedError: SignInAfterSignUpError())

        let state = SignInAfterSignUpState(controller: sut, username: "", slt: slt)
        state.signIn(correlationId: defaultUUID, delegate: mockDelegate)
        
        wait(for: [exp], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }
    
    func test_whenSignInWithSLTTokenReturnError_shouldReturnAnError() {
        let request = MSIDHttpRequest()
        let slt = "signInSLT"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext

        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedError: SignInAfterSignUpError(message: "Invalid Client ID"))

        tokenResponseValidatorMock.tokenValidatedResponse = .error(.invalidClient(message: "Invalid Client ID"))

        let state = SignInAfterSignUpState(controller: sut, username: "", slt: slt)
        state.signIn(correlationId: defaultUUID, delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }
    
    func test_whenSignInWithSLTHaveTokenNil_shouldReturnAnError() {        
        let expectation = expectation(description: "SignInController")

        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedError: SignInAfterSignUpError(message: "Sign In is not available at this point, please use the standalone sign in methods"))

        let state = SignInAfterSignUpState(controller: sut, username: "username", slt: nil)
        state.signIn(correlationId: defaultUUID, delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }

    
    // MARK: private methods

    private func checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: VerifyCodeErrorType, validatorError: MSALNativeAuthTokenValidatedErrorType) {
        let request = MSIDHttpRequest()
        let expectedCredentialToken = "credentialToken"
        let expectedOOBCode = "code"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, credentialToken: expectedCredentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.oobCode, scope: "", password: nil, oobCode: expectedOOBCode, includeChallengeType: true, refreshToken: nil)
        let mockDelegate = SignInVerifyCodeDelegateSpy(expectation: exp, expectedError: VerifyCodeError(type: delegateError))
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)
        
        let state = SignInCodeRequiredState(scopes: [], controller: sut, flowToken: expectedCredentialToken)
        state.submitCode(code: expectedOOBCode, delegate: mockDelegate, correlationId: defaultUUID)

        wait(for: [exp], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkSubmitPasswordPublicErrorWithTokenValidatorError(publicError: PasswordRequiredError, validatorError: MSALNativeAuthTokenValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        let exp = expectation(description: "SignInController")
        
        tokenRequestProviderMock.result = request
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: expectedCredentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: "", password: expectedPassword, oobCode: nil, includeChallengeType: true, refreshToken: nil)
        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: publicError)
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, flowToken: expectedCredentialToken)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate, correlationId: defaultUUID)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError, validatorError: MSALNativeAuthSignInChallengeValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.result = request
        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: "credentialToken")
        signInResponseValidatorMock.challengeValidatedResponse = .error(validatorError)
        
        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError, validatorError: MSALNativeAuthSignInInitiateValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.result = request
        signInResponseValidatorMock.initiateValidatedResponse = .error(validatorError)

        let helper = SignInCodeStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)

        let result = await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil))

        helper.onSignInError(result)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError, validatorError: MSALNativeAuthTokenValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)
        
        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.result = request
        
        let helper = SignInPasswordStartTestsValidatorHelper(expectation: expectation, expectedError: delegateError)
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)
        
        let result = await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil))

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

}
