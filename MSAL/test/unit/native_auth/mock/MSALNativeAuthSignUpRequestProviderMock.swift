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

class MSALNativeAuthSignUpRequestProviderMock: MSALNativeAuthSignUpRequestProviding {
    private var requestStart: MSIDHttpRequest?
    private var requestChallenge: MSIDHttpRequest?
    private var requestContinue: MSIDHttpRequest?
    private var throwErrorStart = false
    private var throwErrorChallenge = false
    private var throwErrorContinue = false
    private(set) var startCalled = false
    private(set) var challengeCalled = false
    private(set) var continueCalled = false
    var expectedStartRequestParameters: MSALNativeAuthSignUpStartRequestProviderParameters!
    var expectedChallengeRequestParameters: (token: String, context: MSIDRequestContext)!
    var expectedContinueRequestParameters: MSALNativeAuthSignUpContinueRequestProviderParams!

    func mockStartRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        self.requestStart = request
        self.throwErrorStart = throwError
    }

    func start(parameters: MSAL.MSALNativeAuthSignUpStartRequestProviderParameters) throws -> MSIDHttpRequest {
        startCalled = true
        checkStartParameters(params: parameters)
        
        if let request = requestStart {
            return request
        } else if throwErrorStart {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockStartRequestFunc()")
        }
    }

    private func checkStartParameters(params: MSALNativeAuthSignUpStartRequestProviderParameters) {
        XCTAssertEqual(params.username, expectedStartRequestParameters.username)
        XCTAssertEqual(params.password, expectedStartRequestParameters.password)
        XCTAssertEqual(params.context.correlationId(), expectedStartRequestParameters.context.correlationId())
        XCTAssertNotNil(params.attributes)
        XCTAssertEqual(params.attributes?["key"] as? String, expectedStartRequestParameters.attributes?["key"] as? String)
    }

    func mockChallengeRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        self.requestChallenge = request
        self.throwErrorChallenge = throwError
    }

    func challenge(token: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        challengeCalled = true
        checkChallengeParameters(token: token, context: context)

        if let request = requestChallenge {
            return request
        } else if throwErrorChallenge {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockChallengeRequestFunc()")
        }
    }

    private func checkChallengeParameters(token: String, context: MSIDRequestContext) {
        XCTAssertEqual(token, expectedChallengeRequestParameters.token)
        XCTAssertEqual(context.correlationId(), expectedChallengeRequestParameters.context.correlationId())
    }

    func mockContinueRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        self.requestContinue = request
        self.throwErrorContinue = throwError
    }

    func `continue`(parameters: MSAL.MSALNativeAuthSignUpContinueRequestProviderParams) throws -> MSIDHttpRequest {
        continueCalled = true
        checkContinueParameters(parameters)

        if let request = requestContinue {
            return request
        } else if throwErrorContinue {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockContinueRequestFunc()")
        }
    }

    private func checkContinueParameters(_ params: MSALNativeAuthSignUpContinueRequestProviderParams) {
        XCTAssertEqual(params.grantType, expectedContinueRequestParameters.grantType)
        XCTAssertEqual(params.continuationToken, expectedContinueRequestParameters.continuationToken)
        XCTAssertEqual(params.password, expectedContinueRequestParameters.password)
        XCTAssertEqual(params.oobCode, expectedContinueRequestParameters.oobCode)
        XCTAssertEqual(params.attributes?["key"] as? String, expectedContinueRequestParameters.attributes?["key"] as? String)
        XCTAssertEqual(params.context.correlationId(), expectedContinueRequestParameters.context.correlationId())
    }
}
