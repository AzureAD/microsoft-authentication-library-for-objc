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

class MSALNativeAuthMFAControllerTests: MSALNativeAuthSignInControllerTests {
    
    func test_signInWithCodeSubmitCodeReceiveStrongAuthRequired_anErrorShouldBeReturned() {
        let continuationToken = "continuationToken"
        let expectedError = VerifyCodeError(type: .generalError, correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        tokenResponseValidatorMock.tokenValidatedResponse = .strongAuthRequired(continuationToken: continuationToken)

        let state = SignInCodeRequiredState(scopes: [], controller: sut, inputValidator: MSALNativeAuthInputValidator(), continuationToken: continuationToken, correlationId: defaultUUID)
        let delegate = SignInVerifyCodeDelegateSpy(expectation: expectation, expectedError: expectedError)
        state.submitCode(code: "code", delegate: delegate)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: false)
    }
    
    func test_whenSignInWithCodeReceiveIntrospectRequired_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: expectedCredentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .introspectRequired
        
        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: nil, context: expectedContext, scopes: nil))

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithCodeStart, isSuccessful: false)
        if case .error(let error) = result.result {
            XCTAssertEqual(error.type, .generalError)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenSignInWithPassowordReceiveIntrospectRequired_errorShouldBeReturned() async {
        let expectedUsername = "username"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: expectedCredentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .introspectRequired
        
        let result = await sut.signIn(params: MSALNativeAuthSignInParameters(username: expectedUsername, password: "pwd", context: expectedContext, scopes: nil))

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdSignInWithPasswordStart, isSuccessful: false)
        if case .error(let error) = result.result {
            XCTAssertEqual(error.type, .generalError)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenRequestChallengeDefaultStrongAuth_VerificationRequiredIsSentBackToUser() async {
        let expectedContinuationToken = "continuationToken"
        let expectedSentTo = "sentTo"
        let expectedChannelType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 8
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(
            continuationToken: expectedContinuationToken,
            sentTo: expectedSentTo,
            channelType: expectedChannelType,
            codeLength: expectedCodeLength
        )
        let result = await sut.requestChallenge(continuationToken: expectedContinuationToken, authMethod: nil, context: expectedContext, scopes: [])
        result.telemetryUpdate?(.success(()))

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: true)
        if case .verificationRequired(let sentTo, let channelTargetType, let codeLength, let newState) = result.result {
            XCTAssertEqual(sentTo, expectedSentTo)
            XCTAssertEqual(channelTargetType, expectedChannelType)
            XCTAssertEqual(codeLength, expectedCodeLength)
            XCTAssertEqual(newState.continuationToken, expectedContinuationToken)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }
    
    func test_whenRequestChallengeDefaultStrongAuth_SelectionRequiredIsSentBackToUser() async {
        let expectedContinuationToken = "continuationToken"
        let internalAuthMethod = MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "hint")
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.challengeValidatedResponse = .introspectRequired
        signInResponseValidatorMock.introspectValidatedResponse = .authMethodsRetrieved(continuationToken: expectedContinuationToken, authMethods: [internalAuthMethod])
        let result = await sut.requestChallenge(continuationToken: expectedContinuationToken, authMethod: nil, context: expectedContext, scopes: [])
        result.telemetryUpdate?(.success(()))

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: true)
        if case .selectionRequired(let authMethods, let newState) = result.result {
            XCTAssertEqual(authMethods.count, 1)
            XCTAssertEqual(authMethods.first?.challengeType, internalAuthMethod.challengeType.rawValue)
            XCTAssertEqual(authMethods.first?.id, internalAuthMethod.id)
            XCTAssertEqual(authMethods.first?.channelTargetType.value, internalAuthMethod.challengeChannel)
            XCTAssertEqual(authMethods.first?.loginHint, internalAuthMethod.loginHint)
            XCTAssertEqual(newState.continuationToken, expectedContinuationToken)
        } else {
            XCTFail("Expected selectionRequired result")
        }
    }
    
    func test_whenRequestChallengeRequestFails_ErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
    
        let result = await sut.requestChallenge(continuationToken: "continuationToken", authMethod: nil, context: expectedContext, scopes: [])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }
    
    func test_whenRequestChallengeIntrospectRequestFails_ErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.throwingIntrospectError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
        signInResponseValidatorMock.challengeValidatedResponse = .introspectRequired
    
        let result = await sut.requestChallenge(continuationToken: "continuationToken", authMethod: nil, context: expectedContext, scopes: [])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenRequestChallengeCustomStrongAuth_VerificationRequiredIsSentBackToUser() async {
        let expectedContinuationToken = "continuationToken"
        let expectedSentTo = "sentTo"
        let expectedChannelType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 8
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedAuthMethod = MSALAuthMethod(id: "id", challengeType: "oob", loginHint: "**", channelTargetType: MSALNativeAuthChannelType(value: "email"))

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedMFAAuthMethodId = expectedAuthMethod.id
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(
            continuationToken: expectedContinuationToken,
            sentTo: expectedSentTo,
            channelType: expectedChannelType,
            codeLength: expectedCodeLength
        )
        let result = await sut.requestChallenge(continuationToken: expectedContinuationToken, authMethod: expectedAuthMethod, context: expectedContext, scopes: [])
        result.telemetryUpdate?(.success(()))

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: true)
        if case .verificationRequired(let sentTo, let channelTargetType, let codeLength, let newState) = result.result {
            XCTAssertEqual(sentTo, expectedSentTo)
            XCTAssertEqual(channelTargetType, expectedChannelType)
            XCTAssertEqual(codeLength, expectedCodeLength)
            XCTAssertEqual(newState.continuationToken, expectedContinuationToken)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }
    
    func test_whenRequestChallengePasswordRequiredResponse_anErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedContinuationToken = "continuationToken"

        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: expectedContinuationToken)

        let result = await sut.requestChallenge(continuationToken: expectedContinuationToken, authMethod: nil, context: expectedContext, scopes: [])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNil(newState)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenGetAuthMethodsIntrospectRequestFail_anErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingIntrospectError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
    
        let result = await sut.getAuthMethods(continuationToken: "CT", context: expectedContext, scopes: [])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFAGetAuthMethods, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenGetAuthMethodsIntrospectReturnsError_anErrorShouldBeReturned() async {
        await checkGetAuthMethodsWithIntrospectValidatorError(validatedError: .redirect, expectedType: .browserRequired)
        await checkGetAuthMethodsWithIntrospectValidatorError(validatedError: .invalidRequest(.init()), expectedType: .generalError)
        await checkGetAuthMethodsWithIntrospectValidatorError(validatedError: .expiredToken(.init()), expectedType: .generalError)
        await checkGetAuthMethodsWithIntrospectValidatorError(validatedError: .unexpectedError(.init()), expectedType: .generalError)
    }
    
    func test_whenGetAuthMethods_correctResultShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let internalAuthMethod = MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "hint")
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.introspectValidatedResponse = .authMethodsRetrieved(continuationToken: expectedContinuationToken, authMethods: [internalAuthMethod])
        
        let result = await sut.getAuthMethods(continuationToken: expectedContinuationToken, context: expectedContext, scopes: [])
        result.telemetryUpdate?(.success(()))

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFAGetAuthMethods, isSuccessful: true)
        if case .selectionRequired(let authMethods, let newState) = result.result {
            XCTAssertEqual(authMethods.count, 1)
            XCTAssertEqual(authMethods.first?.challengeType, internalAuthMethod.challengeType.rawValue)
            XCTAssertEqual(authMethods.first?.id, internalAuthMethod.id)
            XCTAssertEqual(authMethods.first?.channelTargetType.value, internalAuthMethod.challengeChannel)
            XCTAssertEqual(authMethods.first?.loginHint, internalAuthMethod.loginHint)
            XCTAssertEqual(newState.continuationToken, expectedContinuationToken)
        } else {
            XCTFail("Expected selectionRequired result")
        }
    }
    
    func test_whenSubmitChallengeTokenRequestFails_correctErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        tokenRequestProviderMock.mockRequestTokenFunc(nil, throwError: MSALNativeAuthError(message: nil, correlationId: defaultUUID))
        
        let result = await sut.submitChallenge(challenge: "1234", continuationToken: "CT", context: expectedContext, scopes: [])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFASubmitChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenSubmitChallengeTokenRequestReturnError_correctErrorShouldBeReturned() async {
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .authorizationPending(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .generalError(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .expiredToken(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .expiredRefreshToken(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .unauthorizedClient(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .invalidRequest(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .unexpectedError(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .userNotFound(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .invalidPassword(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .invalidOOBCode(.init()), expectedErrorType: .invalidChallenge)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .unsupportedChallengeType(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .invalidScope(.init()), expectedErrorType: .generalError)
        await checkSubmitChallengeWithTokenValidatorError(validatedError: .slowDown(.init()), expectedErrorType: .generalError)
    }
    
    func test_whenSubmitChallengeThirdFactorRequired_correctErrorShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let expectedChallenge = "1234"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScope = "scope1"
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenResponseValidatorMock.tokenValidatedResponse = .strongAuthRequired(continuationToken: expectedContinuationToken)
        
        let result = await sut.submitChallenge(challenge: expectedChallenge, continuationToken: expectedContinuationToken, context: expectedContext, scopes: [expectedScope])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFASubmitChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenSubmitChallenge_signInShouldBeCompletedSuccessfully() async {
        let expectedContinuationToken = "continuationToken"
        let expectedChallenge = "1234"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        tokenResponseValidatorMock.expectedTokenResponse = tokenResponse
        cacheAccessorMock.mockUserAccounts = [MSALNativeAuthUserAccountResultStub.account]
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let result = await sut.submitChallenge(challenge: expectedChallenge, continuationToken: expectedContinuationToken, context: expectedContext, scopes: [])
        result.telemetryUpdate?(.success(()))

        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFASubmitChallenge, isSuccessful: true)
        guard case let .completed(result) = result.result else {
            return XCTFail("Result should be .completed")
        }
    }
    
    // MARK: Private methods
    
    private func checkGetAuthMethodsWithIntrospectValidatorError(validatedError: MSALNativeAuthSignInIntrospectValidatedErrorType, expectedType: MFAError.ErrorType) async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.introspectValidatedResponse = .error(validatedError)
        let result = await sut.getAuthMethods(continuationToken: "CT", context: expectedContext, scopes: [])
        
        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFAGetAuthMethods, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, expectedType)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected error result")
        }
        receivedEvents.removeAll()
    }
    
    private func checkSubmitChallengeWithTokenValidatorError(validatedError: MSALNativeAuthTokenValidatedErrorType, expectedErrorType: MFASubmitChallengeError.ErrorType) async {
        let expectedContinuationToken = "continuationToken"
        let expectedChallenge = "1234"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScope = "scope1"
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: expectedContinuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScope, password: nil, oobCode: expectedChallenge, includeChallengeType: true, refreshToken: nil)
        
        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatedError)
        
        let result = await sut.submitChallenge(challenge: expectedChallenge, continuationToken: expectedContinuationToken, context: expectedContext, scopes: [expectedScope])

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFASubmitChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, expectedErrorType)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected error result")
        }
        receivedEvents.removeAll()
    }
}
