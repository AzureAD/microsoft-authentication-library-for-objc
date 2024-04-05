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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthResetPasswordRequestProviderMock: MSALNativeAuthResetPasswordRequestProviding {
    // MARK: Start

    var requestStart: MSIDHttpRequest?
    var throwErrorStart = false
    private(set) var startCalled = false
    var expectedStartRequestParameters: MSALNativeAuthResetPasswordStartRequestProviderParameters!

    func mockStartRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        requestStart = request
        throwErrorStart = throwError
    }

    func start(parameters: MSAL.MSALNativeAuthResetPasswordStartRequestProviderParameters) throws -> MSIDHttpRequest {
        startCalled = true
        checkParameters(params: parameters)

        if let request = requestStart {
            return request
        } else if throwErrorStart {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockStartRequestFunc()")
        }
    }

    private func checkParameters(params: MSALNativeAuthResetPasswordStartRequestProviderParameters) {
        XCTAssertEqual(params.username, expectedStartRequestParameters.username)
        XCTAssertEqual(params.context.correlationId(), expectedStartRequestParameters.context.correlationId())
    }

    // MARK: Challenge

    var requestChallenge: MSIDHttpRequest?
    var throwErrorChallenge = false
    private(set) var challengeCalled = false
    var expectedChallengeRequestParameters: (token: String, context: MSIDRequestContext)!

    func mockChallengeRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        requestChallenge = request
        throwErrorChallenge = throwError
    }

    func challenge(token: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        challengeCalled = true
        checkParameters(token: token, context: context)

        if let request = requestChallenge {
            return request
        } else if throwErrorChallenge {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockChallengeRequestFunc()")
        }
    }

    private func checkParameters(token: String, context: MSIDRequestContext) {
        XCTAssertEqual(token, expectedChallengeRequestParameters.token)
        XCTAssertEqual(context.correlationId(), expectedChallengeRequestParameters.context.correlationId())
    }

    // MARK: Continue

    var requestContinue: MSIDHttpRequest?
    var throwErrorContinue = false
    private(set) var continueCalled = false
    var expectedContinueRequestParameters: MSALNativeAuthResetPasswordContinueRequestParameters!

    func mockContinueRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        requestContinue = request
        throwErrorContinue = throwError
    }

    func `continue`(parameters: MSAL.MSALNativeAuthResetPasswordContinueRequestParameters) throws -> MSIDHttpRequest {
        continueCalled = true
        checkParameters(parameters)

        if let request = requestContinue {
            return request
        } else if throwErrorContinue {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockContinueRequestFunc()")
        }
    }

    private func checkParameters(_ params: MSALNativeAuthResetPasswordContinueRequestParameters) {
        XCTAssertEqual(params.grantType, expectedContinueRequestParameters.grantType)
        XCTAssertEqual(params.continuationToken, expectedContinueRequestParameters.continuationToken)
        XCTAssertEqual(params.oobCode, expectedContinueRequestParameters.oobCode)
        XCTAssertEqual(params.context.correlationId(), expectedContinueRequestParameters.context.correlationId())
    }

    // MARK: Submit

    var requestSubmit: MSIDHttpRequest?
    var throwErrorSubmit = false
    private(set) var submitCalled = false
    var expectedSubmitRequestParameters: MSALNativeAuthResetPasswordSubmitRequestParameters!

    func mockSubmitRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        requestSubmit = request
        throwErrorSubmit = throwError
    }

    func submit(parameters: MSAL.MSALNativeAuthResetPasswordSubmitRequestParameters) throws -> MSIDHttpRequest {
        submitCalled = true
        checkParameters(parameters)

        if let request = requestSubmit {
            return request
        } else if throwErrorSubmit {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockSubmitRequestFunc()")
        }
    }

    private func checkParameters(_ params: MSALNativeAuthResetPasswordSubmitRequestParameters) {
        XCTAssertEqual(params.continuationToken, expectedSubmitRequestParameters.continuationToken)
        XCTAssertEqual(params.newPassword, expectedSubmitRequestParameters.newPassword)
        XCTAssertEqual(params.context.correlationId(), expectedSubmitRequestParameters.context.correlationId())
    }

    // MARK: PollCompletion

    var requestPollCompletion: MSIDHttpRequest?
    var throwErrorPollCompletion = false
    private(set) var pollCompletionCalled = false
    var expectedPollCompletionParameters: MSALNativeAuthResetPasswordPollCompletionRequestParameters!

    func mockPollCompletionRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        requestPollCompletion = request
        throwErrorPollCompletion = throwError
    }

    func pollCompletion(parameters: MSAL.MSALNativeAuthResetPasswordPollCompletionRequestParameters) throws -> MSIDHttpRequest {
        pollCompletionCalled = true
        checkParameters(parameters)

        if let request = requestPollCompletion {
            return request
        } else if throwErrorPollCompletion {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockPollCompletionRequestFunc()")
        }
    }

    private func checkParameters(_ params: MSALNativeAuthResetPasswordPollCompletionRequestParameters) {
        XCTAssertEqual(params.continuationToken, expectedPollCompletionParameters.continuationToken)
        XCTAssertEqual(params.context.correlationId(), expectedPollCompletionParameters.context.correlationId())
    }
}
