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
    private var requestProviderMock: MSALNativeAuthSignInRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var responseValidatorMock: MSALNativeAuthSignInResponseValidatorMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var tokenResult = MSIDTokenResult()
    private var tokenResponse = MSIDAADTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private let defaultScopes = "openid profile offline_access"

    override func setUpWithError() throws {
        requestProviderMock = .init()
        cacheAccessorMock = .init()
        responseValidatorMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        
        sut = .init(
            clientId: DEFAULT_TEST_CLIENT_ID,
            requestProvider: requestProviderMock,
            cacheAccessor: cacheAccessorMock,
            factory: MSALNativeAuthResultFactoryMock(),
            responseValidator: responseValidatorMock
        )
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        try super.setUpWithError()
    }
    
    // MARK: sign in with username and password tests

    func test_whenCreateRequestFails_shouldReturnError() async throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: defaultScopes, password: expectedPassword, oobCode: nil, addNcaFlag: true, includeChallengeType: true)
        requestProviderMock.throwingError = ErrorMock.error

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func test_whenUserSpecifiesScope_defaultScopesShouldBeIncluded() async throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil, addNcaFlag: true, includeChallengeType: true)
        requestProviderMock.throwingError = ErrorMock.error

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "scope2"]), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func test_whenUserSpecifiesScopes_NoDuplicatedScopeShouldBeSent() async throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScopes = "scope1 openid profile offline_access"
        
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(context: expectedContext, username: expectedUsername, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil, addNcaFlag: true, includeChallengeType: true)
        requestProviderMock.throwingError = ErrorMock.error

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: SignInPasswordStartError(type: .generalError))
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: ["scope1", "openid", "profile"]), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func test_successfulResponseAndValidation_shouldCompleteSignIn() async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        requestProviderMock.result = request
        requestProviderMock.expectedUsername = expectedUsername
        requestProviderMock.expectedContext = expectedContext
        
        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedUserAccount: MSALNativeAuthUserAccount(username: "username", accessToken: "accessToken", rawIdToken: "IdToken", scopes: [], expiresOn: Date()))
        
        responseValidatorMock.tokenValidatedResponse = .success(tokenResult, tokenResponse)
        responseValidatorMock.expectedTokenResponse = tokenResponse
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.saveTokenWasCalled)
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
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        requestProviderMock.result = request
        requestProviderMock.expectedCredentialToken = "credentialToken"
        
        let expectation = expectation(description: "SignInController")

        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .browserRequired, message: MSALNativeAuthErrorMessage.unsupportedMFA))

        responseValidatorMock.tokenValidatedResponse = .error(.strongAuthRequired)

        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
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

        requestProviderMock.result = request
        requestProviderMock.expectedUsername = expectedUsername
        requestProviderMock.expectedCredentialToken = credentialToken
        requestProviderMock.expectedContext = expectedContext

        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedSentTo: sentTo, expectedChannelTargetType: channelTargetType, expectedCodeLength: codeLength)

        responseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        responseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: sentTo, channelType: channelTargetType, codeLength: codeLength)

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        wait(for: [expectation], timeout: 1)
    }

    func test_afterSignInWithCodeSubmitCode_signInShouldCompleteSuccessfully() {
        let request = MSIDHttpRequest()
        let credentialToken = "credentialToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        requestProviderMock.result = request
        requestProviderMock.expectedContext = expectedContext
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(context: expectedContext, username: nil, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.oobCode, scope: defaultScopes, password: nil, oobCode: "code", addNcaFlag: false, includeChallengeType: false)

        let state = SignInCodeRequiredState(scopes: ["openid","profile","offline_access"], controller: sut, inputValidator: MSALNativeAuthInputValidator(), flowToken: credentialToken)
        responseValidatorMock.tokenValidatedResponse = .success(tokenResult, tokenResponse)
        state.submitCode(code: "code", delegate: SignInVerifyCodeDelegateSpy(expectation: expectation, expectedUserAccount: MSALNativeAuthUserAccount(username: "username", accessToken: "accessToken", rawIdToken: "IdToken", scopes: [], expiresOn: Date())), correlationId: UUID(uuidString: DEFAULT_TEST_UID)!)

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(cacheAccessorMock.saveTokenWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: true)
    }
    
    func test_whenSignInWithCodeStartAndInitiateRequestCreationFail_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        requestProviderMock.expectedUsername = expectedUsername
        requestProviderMock.expectedContext = expectedContext
        requestProviderMock.throwingError = MSALNativeAuthGenericError()

        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: SignInCodeStartError(type: .generalError))

        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        wait(for: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeStartAndInitiateReturnError_properErrorShouldBeReturned() async {
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError(type: .browserRequired), validatorError: .redirect)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient), validatorError: .invalidClient)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError(type: .userNotFound), validatorError: .userNotFound)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError(type: .generalError), validatorError: .unsupportedChallengeType)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError(type: .generalError), validatorError: .invalidRequest)
        await checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError(type: .generalError), validatorError: .invalidServerResponse)
    }
    
    // MARK: private methods
    
    func checkCodeStartDelegateErrorWithInitiateValidatorError(delegateError: SignInCodeStartError, validatorError: MSALNativeAuthSignInInitiateValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        requestProviderMock.expectedUsername = expectedUsername
        requestProviderMock.expectedContext = expectedContext
        requestProviderMock.result = request
        responseValidatorMock.initiateValidatedResponse = .error(validatorError)

        let mockCodeStartDelegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: delegateError)
        await sut.signIn(params: MSALNativeAuthSignInWithCodeParameters(username: expectedUsername, context: expectedContext, scopes: nil), delegate: mockCodeStartDelegate)

        wait(for: [expectation], timeout: 1)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        receivedEvents.removeAll()
    }
    
    private func checkDelegateErrorWithValidatorError(delegateError: SignInPasswordStartError, validatorError: MSALNativeAuthSignInTokenValidatedErrorType) async {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        let expectation = expectation(description: "SignInController")

        requestProviderMock.result = request
        
        let mockDelegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: delegateError)
        responseValidatorMock.tokenValidatedResponse = .error(validatorError)
        
        await sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, context: expectedContext, scopes: nil), delegate: mockDelegate)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
        receivedEvents.removeAll()
        wait(for: [expectation], timeout: 1)
    }
    
    private func checkTelemetryEventResult(id: MSALNativeAuthTelemetryApiId, isSuccessful: Bool) {
        XCTAssertEqual(receivedEvents.count, 1)

        guard let telemetryEventDict = receivedEvents.first?.propertyMap else {
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
