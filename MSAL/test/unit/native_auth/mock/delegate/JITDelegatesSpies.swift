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

open class JITRequestChallengeDelegateSpy: RegisterStrongAuthChallengeDelegate {

    let expectation: XCTestExpectation
    var expectedError: RegisterStrongAuthChallengeError?
    var expectedResult: MSALNativeAuthUserAccountResult?
    private(set) var newState: RegisterStrongAuthState?
    private(set) var verificationResult: MSALNativeAuthRegisterStrongAuthVerificationRequiredResult?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation, expectedResult: MSALNativeAuthUserAccountResult?, expectedError: RegisterStrongAuthChallengeError?) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedResult = expectedResult
    }

    public func onRegisterStrongAuthChallengeError(error: RegisterStrongAuthChallengeError, newState: RegisterStrongAuthState?) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            self.newState = newState
            checkErrors(error: error, expectedError: expectedError)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }

    public func onRegisterStrongAuthVerificationRequired(result: MSALNativeAuthRegisterStrongAuthVerificationRequiredResult) {
        XCTAssertTrue(Thread.isMainThread)
        self.verificationResult = result
        self.sentTo = result.sentTo
        self.channelTargetType = result.channelTargetType
        self.codeLength = result.codeLength
        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        if let expectedResult = expectedResult {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(expectedResult.idToken, result.idToken)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }
}

open class JITRequestChallengeNotImplementedDelegateSpy: RegisterStrongAuthChallengeDelegate {

    let expectation: XCTestExpectation
    let expectedError: RegisterStrongAuthChallengeError

    init(expectation: XCTestExpectation, expectedError: RegisterStrongAuthChallengeError) {
        self.expectation = expectation
        self.expectedError = expectedError
    }

    public func onRegisterStrongAuthChallengeError(error: RegisterStrongAuthChallengeError, newState: RegisterStrongAuthState?) {
        XCTAssertTrue(Thread.isMainThread)
        checkErrors(error: error, expectedError: expectedError)
        XCTAssertNil(newState)
        expectation.fulfill()
    }
}

open class JITSubmitChallengeDelegateSpy: RegisterStrongAuthSubmitChallengeDelegate {

    let expectation: XCTestExpectation
    var expectedError: RegisterStrongAuthSubmitChallengeError?
    var expectedResult: MSALNativeAuthUserAccountResult?
    private(set) var newState: RegisterStrongAuthVerificationRequiredState?

    init(expectation: XCTestExpectation, expectedResult: MSALNativeAuthUserAccountResult?, expectedError: RegisterStrongAuthSubmitChallengeError?) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedResult = expectedResult
    }

    public func onRegisterStrongAuthSubmitChallengeError(error: RegisterStrongAuthSubmitChallengeError, newState: RegisterStrongAuthVerificationRequiredState?) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            self.newState = newState
            checkErrors(error: error, expectedError: expectedError)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        if let expectedResult = expectedResult {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(expectedResult.idToken, result.idToken)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }
}

open class JITSubmitChallengeNotImplementedDelegateSpy: RegisterStrongAuthSubmitChallengeDelegate {

    let expectation: XCTestExpectation
    let expectedError: RegisterStrongAuthSubmitChallengeError

    init(expectation: XCTestExpectation, expectedError: RegisterStrongAuthSubmitChallengeError) {
        self.expectation = expectation
        self.expectedError = expectedError
    }

    public func onRegisterStrongAuthSubmitChallengeError(error: RegisterStrongAuthSubmitChallengeError, newState: RegisterStrongAuthVerificationRequiredState?) {
        XCTAssertTrue(Thread.isMainThread)
        checkErrors(error: error, expectedError: expectedError)
        XCTAssertNil(newState)
        expectation.fulfill()
    }
}

fileprivate func checkErrors(error: MSALNativeAuthError, expectedError: MSALNativeAuthError?) {
    XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
    XCTAssertEqual(error.errorCodes, expectedError?.errorCodes)
    XCTAssertEqual(error.errorUri, expectedError?.errorUri)
    XCTAssertEqual(error.correlationId, expectedError?.correlationId)
}
