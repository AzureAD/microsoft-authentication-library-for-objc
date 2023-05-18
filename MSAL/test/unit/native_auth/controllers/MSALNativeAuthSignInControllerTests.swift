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
    private var factoryMock: MSALNativeAuthResultFactoryMock!
    private var tokenResult = MSIDTokenResult()
    private var tokenResponse = MSIDAADTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    
    private var requestSignInTokenParamsStub: MSALNativeAuthSignInTokenRequestParameters {
        .init(
            config: MSALNativeAuthConfigStubs.configuration,
            context: contextMock,
            username: "username",
            credentialToken: nil,
            signInSLT: nil,
            grantType: .password,
            scope: "scope",
            password: "password",
            oobCode: nil
        )
    }
    
    private var requestSignInChallengeRequestParamsStub: MSALNativeAuthSignInChallengeRequestParameters {
        .init(
            config: MSALNativeAuthConfigStubs.configuration,
            context: contextMock,
            credentialToken: "credentialToken"
        )
    }

    private let tokenResponseDict: [String: Any] = [
        "token_type": "Bearer",
        "scope": "openid profile email",
        "expires_in": 4141,
        "ext_expires_in": 4141,
        "access_token": "accessToken",
        "refresh_token": "refreshToken",
        "id_token": "idToken"
    ]

    private var nativeAuthResponse: MSALNativeAuthResponse {
        .init(
            stage: .completed,
            credentialToken: nil,
            authentication: .init(
                accessToken: "<access_token>",
                idToken: "<id_token>",
                scopes: ["<scope_1>, <scope_2>"],
                expiresOn: Date(),
                tenantId: "myTenant"
            )
        )
    }

    override func setUpWithError() throws {
        requestProviderMock = .init()
        cacheAccessorMock = .init()
        responseValidatorMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        factoryMock = .init()
        
        sut = .init(
            clientId: DEFAULT_TEST_CLIENT_ID,
            requestProvider: requestProviderMock,
            cacheAccessor: cacheAccessorMock,
            factory: factoryMock,
            responseValidator: responseValidatorMock
        )
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        try super.setUpWithError()
    }

    func test_whenCreateRequestFails_shouldReturnError() throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)
        let expectedScopes = "openid,profile,offline_access"
        
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(config: MSALNativeAuthConfigStubs.configuration, context: expectedContext, username: expectedUsername, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil)
        requestProviderMock.throwingError = ErrorMock.error
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)

        let mockDelegate = SignInStartDelegateSpy(expectation: expectation, expectedError: SignInStartError(type: .generalError))
        
        sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, correlationId: expectedContext.correlationId(), scopes: nil), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func test_whenUserSpecifiesScope_defaultScopesShouldBeIncluded() throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)
        let expectedScopes = "scope1,scope2,openid,profile,offline_access"
        
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(config: MSALNativeAuthConfigStubs.configuration, context: expectedContext, username: expectedUsername, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil)
        requestProviderMock.throwingError = ErrorMock.error
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)

        let mockDelegate = SignInStartDelegateSpy(expectation: expectation, expectedError: SignInStartError(type: .generalError))
        
        sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, correlationId: expectedContext.correlationId(), scopes: ["scope1", "scope2"]), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func test_whenUserSpecifiesScopes_NoDuplicatedScopeShouldBeSent() throws {
        let expectation = expectation(description: "SignInController")

        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)
        let expectedScopes = "scope1,openid,profile,offline_access"
        
        requestProviderMock.expectedTokenParams = MSALNativeAuthSignInTokenRequestParameters(config: MSALNativeAuthConfigStubs.configuration, context: expectedContext, username: expectedUsername, credentialToken: nil, signInSLT: nil, grantType: MSALNativeAuthGrantType.password, scope: expectedScopes, password: expectedPassword, oobCode: nil)
        requestProviderMock.throwingError = ErrorMock.error
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)

        let mockDelegate = SignInStartDelegateSpy(expectation: expectation, expectedError: SignInStartError(type: .generalError))
        
        sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, correlationId: expectedContext.correlationId(), scopes: ["scope1", "openid", "profile"]), delegate: mockDelegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func test_successfulResponseAndValidation_shouldCompleteSignIn() {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignInController")

        requestProviderMock.result = request
        requestProviderMock.expectedUsername = expectedUsername
        requestProviderMock.expectedContext = expectedContext
        
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        
        let mockDelegate = SignInStartDelegateSpy(expectation: expectation, expectedUserAccount: MSALNativeAuthUserAccount(username: "username", accessToken: "accessToken", rawIdToken: "IdToken", scopes: [], expiresOn: Date()))
        
        responseValidatorMock.tokenValidatesResponse = .success(tokenResult, tokenResponse)
        responseValidatorMock.expectedTokenResponse = tokenResponse
        
        sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, correlationId: expectedContext.correlationId(), scopes: nil), delegate: mockDelegate)
        
        XCTAssertTrue(cacheAccessorMock.saveTokenWasCalled)

        checkTelemetryEventsForSuccessfulResult()
        wait(for: [expectation], timeout: 1)
    }
    
    func test_whenCredentialsAreRequired_checkCredentialTokenIsPassedToValidator() {
        let result = MSIDHttpRequest()
        requestProviderMock.result = result
        requestProviderMock.expectedCredentialToken = requestSignInChallengeRequestParamsStub.credentialToken
        
        HttpModuleMockConfigurator.configure(request: result, responseJson: tokenResponseDict)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)

        let mockDelegate = SignInStartDelegateFailureSpy()

        responseValidatorMock.tokenValidatesResponse = .credentialRequired(requestSignInChallengeRequestParamsStub.credentialToken)

        sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, correlationId: expectedContext.correlationId(), scopes: nil), delegate: mockDelegate)
    }

    func test_whenErrorIsReturnedFromValidator_itIsCorrectlyTranslatedToDelegateError() {
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .generalError)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .expiredToken)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .authorizationPending)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .slowDown)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidRequest)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError), validatorError: .invalidServerResponse)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Invalid Client ID"), validatorError: .invalidClient)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Unsupported challenge type"), validatorError: .unsupportedChallengeType)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .generalError, message: "Invalid scope"), validatorError: .invalidScope)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .userNotFound), validatorError: .userNotFound)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .invalidPassword), validatorError: .invalidPassword)
        checkDelegateErrorWithValidatorError(delegateError: SignInStartError(type: .invalidAuthenticationType), validatorError: .invalidAuthenticationType)
    }
    
    // MARK: private methods
    
    private func checkDelegateErrorWithValidatorError(delegateError: SignInStartError, validatorError: MSALNativeAuthSignInTokenValidatedErrorType) {
        let request = MSIDHttpRequest()
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedContext = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)
        
        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignInController")

        requestProviderMock.result = request
        
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        
        let mockDelegate = SignInStartDelegateSpy(expectation: expectation, expectedError: delegateError)
        responseValidatorMock.tokenValidatesResponse = .error(validatorError)
        
        sut.signIn(params: MSALNativeAuthSignInWithPasswordParameters(username: expectedUsername, password: expectedPassword, correlationId: expectedContext.correlationId(), scopes: nil), delegate: mockDelegate)
        
        checkTelemetryEventsForFailedResult()
        receivedEvents.removeAll()
        wait(for: [expectation], timeout: 1)
    }
    
    private func checkTelemetryEventsForSuccessfulResult() {
        guard receivedEvents.count == 1, let telemetryEventDict = receivedEvents[0].propertyMap else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdSignInWithPasswordStart.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event")
        XCTAssertEqual(telemetryEventDict["correlation_id"] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, "yes")
        XCTAssertEqual(telemetryEventDict["status"] as? String, "succeeded")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
        XCTAssertNotNil(telemetryEventDict["request_id"])
    }

    private func checkTelemetryEventsForFailedResult() {
        guard receivedEvents.count == 1, let telemetryEventDict = receivedEvents[0].propertyMap else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdSignInWithPasswordStart.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event")
        XCTAssertEqual(telemetryEventDict["correlation_id"] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, "no")
        XCTAssertEqual(telemetryEventDict["status"] as? String, "failed")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
        XCTAssertNotNil(telemetryEventDict["request_id"])
    }

}
