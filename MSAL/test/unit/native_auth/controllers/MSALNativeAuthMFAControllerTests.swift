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

class MSALNativeAuthMFAControllerTests: MSALNativeAuthSignInControllerTests {
    
    func test_signInWithCodeSubmitCodeReceiveStrongAuthRequired_AwaitingMFAReturnedCorrectly() {
        let continuationToken = "continuationToken"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let expectation = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        let internalAuthMethod = MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "hint")

        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.introspectValidatedResponse = .authMethodsRetrieved(continuationToken: expectedCredentialToken, authMethods: [internalAuthMethod])

        tokenResponseValidatorMock.tokenValidatedResponse = .strongAuthRequired(continuationToken: continuationToken)

        let state = SignInCodeRequiredState(scopes: [], controller: sut, inputValidator: MSALNativeAuthInputValidator(), claimsRequestJson: nil, continuationToken: continuationToken, correlationId: defaultUUID)
        let delegate = SignInVerifyCodeDelegateSpy(expectation: expectation)
        state.submitCode(code: "code", delegate: delegate)

        wait(for: [expectation], timeout: 1)

        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitCode, isSuccessful: true)
    }

    func test_whenSignInWithCodeSubmitPasswordStrongAuthRequired_AwaitingMFAReturnedCorrectly() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        let internalAuthMethod = MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "hint")

        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.introspectValidatedResponse = .authMethodsRetrieved(continuationToken: expectedCredentialToken, authMethods: [internalAuthMethod])

        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp)
        tokenResponseValidatorMock.tokenValidatedResponse = .strongAuthRequired(continuationToken: "newContinuationToken")

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, claimsRequestJson: nil, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate)

        await fulfillment(of: [exp], timeout: 1)

        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: true)
    }

    func test_whenSignInWithCodeSubmitPassword_requestIntrospectFailsErrorReturnedCorrectly() async {
        let expectedUsername = "username"
        let expectedPassword = "password"
        let expectedCredentialToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        let exp = expectation(description: "SignInController")

        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext

        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.introspectValidatedResponse = .error(.unexpectedError(.init(error: .unknown, errorDescription: "errorDescription", errorCodes: nil, errorURI: nil)))

        let mockDelegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: .init(type: .generalError, message: "errorDescription", correlationId: defaultUUID))
        tokenResponseValidatorMock.tokenValidatedResponse = .strongAuthRequired(continuationToken: "newContinuationToken")

        let state = SignInPasswordRequiredState(scopes: [], username: expectedUsername, controller: sut, claimsRequestJson: nil, continuationToken: expectedCredentialToken, correlationId: defaultUUID)
        state.submitPassword(password: expectedPassword, delegate: mockDelegate)

        await fulfillment(of: [exp], timeout: 1)

        checkTelemetryEventResult(id: .telemetryApiIdSignInSubmitPassword, isSuccessful: false)
    }

    func test_whenRequestChallengeRequestFails_ErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authMethod = MSALAuthMethod(id: "1",
                                        challengeType: "oob",
                                        loginHint: "us**@**oso.com",
                                        channelTargetType: MSALNativeAuthChannelType(value: "email"))

        signInRequestProviderMock.expectedMFAAuthMethodId = "1"
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.throwingChallengeError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)
    
        let result = await sut.requestChallenge(continuationToken: "continuationToken", authMethod: authMethod, context: expectedContext, scopes: [], claimsRequestJson: nil)

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }
    
    func test_whenRequestChallengeCustomStrongAuth_VerificationRequiredIsSentBackToUser() async {
        let expectedContinuationToken = "continuationToken"
        let expectedSentTo = "sentTo"
        let expectedChannelType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 8
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedAuthMethod = MSALAuthMethod(id: "1",
                                                challengeType: "oob",
                                                loginHint: "us**@**oso.com",
                                                channelTargetType: MSALNativeAuthChannelType(value: "email"))

        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedMFAAuthMethodId = expectedAuthMethod.id
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(
            continuationToken: expectedContinuationToken,
            sentTo: expectedSentTo,
            channelType: expectedChannelType,
            codeLength: expectedCodeLength
        )
        let result = await sut.requestChallenge(continuationToken: expectedContinuationToken, authMethod: expectedAuthMethod, context: expectedContext, scopes: [], claimsRequestJson: nil)
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
        let authMethod = MSALAuthMethod(id: "1",
                                        challengeType: "oob",
                                        loginHint: "us**@**oso.com",
                                        channelTargetType: MSALNativeAuthChannelType(value: "email"))
        signInRequestProviderMock.expectedMFAAuthMethodId = "1"
        signInRequestProviderMock.expectedContext = expectedContext
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.challengeValidatedResponse = .passwordRequired(continuationToken: expectedContinuationToken)

        let result = await sut.requestChallenge(continuationToken: expectedContinuationToken, authMethod: authMethod, context: expectedContext, scopes: [], claimsRequestJson: nil)

        XCTAssertFalse(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFARequestChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNil(newState)
        } else {
            XCTFail("Expected error result")
        }
    }
    
    func test_whenSubmitChallengeTokenRequestFails_correctErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        tokenRequestProviderMock.mockRequestTokenFunc(nil, throwError: MSALNativeAuthError(message: nil, correlationId: defaultUUID))
        
        let result = await sut.submitChallenge(challenge: "1234", continuationToken: "CT", context: expectedContext, scopes: [], claimsRequestJson: nil)

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
        let internalAuthMethod = MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "hint")

        signInRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInResponseValidatorMock.introspectValidatedResponse = .authMethodsRetrieved(continuationToken: expectedContinuationToken, authMethods: [internalAuthMethod])
        
        let result = await sut.submitChallenge(challenge: expectedChallenge, continuationToken: expectedContinuationToken, context: expectedContext, scopes: [expectedScope], claimsRequestJson: nil)

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
        let claimsRequestJson = "claims"
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: expectedContinuationToken, grantType: .mfaOOB, scope: "", password: nil, oobCode: expectedChallenge, includeChallengeType: true, refreshToken: nil, claimsRequestJson: claimsRequestJson)

        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        cacheAccessorMock.mockUserAccounts = [MSALNativeAuthUserAccountResultStub.account]
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let result = await sut.submitChallenge(challenge: expectedChallenge, continuationToken: expectedContinuationToken, context: expectedContext, scopes: [], claimsRequestJson: claimsRequestJson)
        result.telemetryUpdate?(.success(()))

        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        checkTelemetryEventResult(id: .telemetryApiIdMFASubmitChallenge, isSuccessful: true)
        guard case let .completed(result) = result.result else {
            return XCTFail("Result should be .completed")
        }
    }
    
    // MARK: Private methods
    
    private func checkSubmitChallengeWithTokenValidatorError(validatedError: MSALNativeAuthTokenValidatedErrorType, expectedErrorType: MFASubmitChallengeError.ErrorType) async {
        let expectedContinuationToken = "continuationToken"
        let expectedChallenge = "1234"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let expectedScope = "scope1"
        
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        tokenRequestProviderMock.expectedContext = expectedContext
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: expectedContext, username: nil, continuationToken: expectedContinuationToken, grantType: MSALNativeAuthGrantType.mfaOOB, scope: expectedScope, password: nil, oobCode: expectedChallenge, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)

        tokenResponseValidatorMock.tokenValidatedResponse = .error(validatedError)
        
        let result = await sut.submitChallenge(challenge: expectedChallenge, continuationToken: expectedContinuationToken, context: expectedContext, scopes: [expectedScope], claimsRequestJson: nil)

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
