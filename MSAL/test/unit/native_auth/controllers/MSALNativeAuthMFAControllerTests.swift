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
}
