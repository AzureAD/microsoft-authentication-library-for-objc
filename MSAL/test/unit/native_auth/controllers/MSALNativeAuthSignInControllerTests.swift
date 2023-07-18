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

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
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

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "scope2"]), delegate: mockDelegate)
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

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "openid", "profile"]), delegate: mockDelegate)
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

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: true)
    }
    
    func test_whenErrorIsReturnedFromValidator_itIsCorrectlyTranslatedToDelegateError() async  {
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .generalError)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .expiredToken)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .authorizationPending)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .slowDown)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .invalidRequest)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError), validatorError: .invalidServerResponse)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Invalid Client ID"), validatorError: .invalidClient)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Unsupported challenge type"), validatorError: .unsupportedChallengeType)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .generalError, message: "Invalid scope"), validatorError: .invalidScope)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .userNotFound), validatorError: .userNotFound)
        await checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError(type: .invalidPassword), validatorError: .invalidPassword)
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

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .browserRequired, message: MSALNativeAuthErrorMessage.unsupportedMFA))

        tokenResponseValidatorMock.tokenValidatedResponse = .error(.strongAuthRequired)

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
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

        let mockPasswordStartDelegate = SignInPasswordStartDelegateSpy(expectation: expectation)
        mockPasswordStartDelegate.expectedSentTo = expectedSentTo
        mockPasswordStartDelegate.expectedChannelTargetType = expectedChannelTargetType
        mockPasswordStartDelegate.expectedCodeLength = expectedCodeLength

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockPasswordStartDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: true)
    }

    func test_whenSignInUsingPassword_apiReturnsChallengeTypeOOB_butUserHasNotImplementedOptioanlCallback_generalErrorShouldBeThrown() async {
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

        let mockPasswordStartDelegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: expectation)
        mockPasswordStartDelegate.expectedError = SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.codeRequiredNotImplemented)

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockPasswordStartDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
    }

    func test_whenSignInUsingPassword_apiReturnsChallengeError_delegateErrorShouldCalled() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"

        let expectation = expectation(description: "SignInController")

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .error(.expiredToken)

        signInRequestProviderMock.result = request
        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedCredentialToken = credentialToken
        signInRequestProviderMock.expectedContext = expectedContext

        let mockPasswordStartDelegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: expectation)
        mockPasswordStartDelegate.expectedError = .init(type: .generalError)

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockPasswordStartDelegate)

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

        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

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
    
    func test_whenSignInWithCodeStartAndInitiateRequestCreationFail_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.expectedUsername = expectedUsername
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingInitError = MSALNativeAuthError()

        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: SignInStartError(type: .generalError))

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeStartAndInitiateReturnError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .browserRequired), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient), validatorError: .invalidClient)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .userNotFound), validatorError: .userNotFound)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .unsupportedChallengeType)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidRequest)
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
        
        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: SignInStartError(type: .generalError))

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeChallengeReturnsError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .browserRequired), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .expiredToken)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidToken)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidRequest)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidServerResponse)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient), validatorError: .invalidClient)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .userNotFound), validatorError: .userNotFound)
        await checkCodeStartDelegateErrorWithChallengeValidatorError(delegateError: SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.unsupportedChallengeType), validatorError: .unsupportedChallengeType)
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
        
        let mockCodeStartDelegate = SignInCodeStartDelegateWithPasswordRequiredSpy(expectation: expectation)

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: true)
        XCTAssertEqual(mockCodeStartDelegate.passwordRequiredState?.flowToken, expectedCredentialToken)
    }
    
    func test_whenSignInWithCodePasswordRequiredMethodIsMissing_errorIsReturned() async {
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
        
        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: SignInStartError(type: .generalError, message: "Implementation of onSignInPasswordRequired required"))

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeSubmitPassword_signInIsCompletedSuccessfully() {
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

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: true)
    }
    
    func test_whenSignInWithCodeSubmitPasswordTokenRequestCreationFail_errorShouldBeReturned() {
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
        
        wait(for: [exp], timeout: 1)
        XCTAssertNotNil(mockDelegate.newPasswordRequiredState)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeSubmitPasswordTokenAPIReturnError_correctErrorShouldBeReturned()  {
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .generalError)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .expiredToken)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .invalidClient)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .invalidRequest)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .invalidServerResponse)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .userNotFound)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .invalidOOBCode)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .unsupportedChallengeType)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .browserRequired), validatorError: .strongAuthRequired)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .invalidScope)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .authorizationPending)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .generalError), validatorError: .slowDown)
        checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError(type: .invalidPassword), validatorError: .invalidPassword)
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
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .expiredToken)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidClient)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidRequest)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidServerResponse)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .userNotFound)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .invalidCode, validatorError: .invalidOOBCode)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .unsupportedChallengeType)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .browserRequired, validatorError: .strongAuthRequired)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidScope)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .authorizationPending)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .slowDown)
        checkSubmitCodeDelegateErrorWithTokenValidatorError(delegateError: .generalError, validatorError: .invalidPassword)
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

        let mockDelegate = SignInResendCodeDelegateSpy(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        await sut.resendCode(credentialToken: credentialToken, context: expectedContext, scopes: [], delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInResendCode, isSuccessful: true)
    }
    
    func test_signInWithCodeResendCodeChallengeCreationFail_errorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        let expectation = expectation(description: "SignInController")

        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError()

        let mockDelegate = SignInResendCodeDelegateSpy(expectation: expectation)

        await sut.resendCode(credentialToken: "credentialToken", context: expectedContext, scopes: [], delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNotNil(mockDelegate.newSignInCodeRequiredState)
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

        let mockDelegate = SignInResendCodeDelegateSpy(expectation: expectation)

        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(credentialToken: credentialToken)

        await sut.resendCode(credentialToken: credentialToken, context: expectedContext, scopes: [], delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNil(mockDelegate.newSignInCodeRequiredState)
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

        let mockDelegate = SignInResendCodeDelegateSpy(expectation: expectation)

        signInResponseValidatorMock.challengeValidatedResponse = .error(.userNotFound)

        await sut.resendCode(credentialToken: credentialToken, context: expectedContext, scopes: [], delegate: mockDelegate)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNotNil(mockDelegate.newSignInCodeRequiredState)
        XCTAssertEqual(mockDelegate.newSignInCodeRequiredState?.flowToken, credentialToken)
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
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, credentialToken: nil, signInSLT: slt, grantType: .slt, scope: defaultScopes, password: nil, oobCode: nil, includeChallengeType: false, refreshToken: nil)

        let userAccountResult = MSALNativeAuthUserAccountResultStub.result
        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedUserAccountResult: userAccountResult)
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse

        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        let state = SignInAfterSignUpState(controller: sut, slt: slt)
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

        let state = SignInAfterSignUpState(controller: sut, slt: slt)
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

        tokenResponseValidatorMock.tokenValidatedResponse = .error(.invalidClient)

        let state = SignInAfterSignUpState(controller: sut, slt: slt)
        state.signIn(correlationId: defaultUUID, delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInAfterSignUp, isSuccessful: false)
    }
    
    func test_whenSignInWithSLTHaveTokenNil_shouldReturnAnError() {        
        let expectation = expectation(description: "SignInController")

        let mockDelegate = SignInAfterSignUpDelegateSpy(expectation: expectation, expectedError: SignInAfterSignUpError(message: "Sign In is not available at this point, please use the standalone sign in methods"))

        let state = SignInAfterSignUpState(controller: sut, slt: nil)
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
    
    private func checkSubmitPasswordDelegateErrorWithTokenValidatorError(delegateError: PasswordRequiredError, validatorError: MSALNativeAuthTokenValidatedErrorType) {
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
        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: delegateError)
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, flowToken: expectedCredentialToken)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate, correlationId: defaultUUID)

        wait(for: [exp], timeout: 1)
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
        
        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: delegateError)

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

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

        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: delegateError)
        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

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
        
        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: delegateError)
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatorError)
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
        
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
