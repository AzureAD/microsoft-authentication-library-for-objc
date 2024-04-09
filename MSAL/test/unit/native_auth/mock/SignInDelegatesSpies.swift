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

@testable import MSAL
import XCTest

open class SignInPasswordStartDelegateSpy: SignInStartDelegate {
    let expectation: XCTestExpectation
    var expectedError: SignInStartError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    var expectedSentTo: String?
    var expectedChannelTargetType: MSALNativeAuthChannelType?
    var expectedCodeLength: Int?
    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    
    init(expectation: XCTestExpectation, expectedError: SignInStartError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    public func onSignInStartError(error: MSAL.SignInStartError) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            checkErrors(error: error, expectedError: expectedError)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }

    public func onSignInCodeRequired(newState: MSAL.SignInCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        XCTAssertTrue(Thread.isMainThread)
        newSignInCodeRequiredState = newState
        expectedSentTo = sentTo
        expectedChannelTargetType = channelTargetType
        expectedCodeLength = codeLength

        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        if let expectedUserAccountResult = expectedUserAccountResult {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }
}

class SignInPasswordRequiredDelegateSpy: SignInPasswordRequiredDelegate {

    private(set) var newPasswordRequiredState: SignInPasswordRequiredState?
    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    let expectation: XCTestExpectation
    var expectedError: PasswordRequiredError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?

    init(expectation: XCTestExpectation, expectedError: PasswordRequiredError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    func onSignInPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignInPasswordRequiredState?) {
        XCTAssertTrue(Thread.isMainThread)
        checkErrors(error: error, expectedError: expectedError)
        newPasswordRequiredState = newState
        expectation.fulfill()
    }

    func onSignInCodeRequired(newState: SignInCodeRequiredState,
                              sentTo: String,
                              channelTargetType: MSALNativeAuthChannelType,
                              codeLength: Int) {
        XCTAssertTrue(Thread.isMainThread)
        newSignInCodeRequiredState = newState
    }

    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        XCTAssertTrue(Thread.isMainThread)
        if let expectedUserAccountResult = expectedUserAccountResult {
            XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }
}

final class SignInPasswordRequiredDelegateOptionalMethodsNotImplemented: SignInPasswordRequiredDelegate {

    private(set) var newPasswordRequiredState: SignInPasswordRequiredState?
    let expectation: XCTestExpectation
    var delegateError: PasswordRequiredError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignInPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignInPasswordRequiredState?) {
        XCTAssertTrue(Thread.isMainThread)
        delegateError = error
        newPasswordRequiredState = newState
        expectation.fulfill()
    }
}

open class SignInPasswordStartDelegateFailureSpy: SignInStartDelegate {

    public func onSignInStartError(error: MSAL.SignInStartError) {
        XCTFail("This method should not be called")
    }

    public func onSignInCodeRequired(newState: MSAL.SignInCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        XCTFail("This method should not be called")
    }

    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        XCTFail("This method should not be called")
    }
}

open class SignInCodeStartDelegateSpy: SignInStartDelegate {

    let expectation: XCTestExpectation
    var expectedError: SignInStartError?
    var expectedSentTo: String?
    var expectedChannelTargetType: MSALNativeAuthChannelType?
    var expectedCodeLength: Int?
    var verifyCodeDelegate: SignInVerifyCodeDelegate?
    var correlationId: UUID?
    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    
    init(expectation: XCTestExpectation, correlationId: UUID? = nil, verifyCodeDelegate: SignInVerifyCodeDelegate? = nil, expectedError: SignInStartError? = nil, expectedSentTo: String? = nil, expectedChannelTargetType: MSALNativeAuthChannelType? = nil, expectedCodeLength: Int? = nil) {
        self.expectation = expectation
        self.verifyCodeDelegate = verifyCodeDelegate
        self.expectedSentTo = expectedSentTo
        self.expectedChannelTargetType = expectedChannelTargetType
        self.expectedCodeLength = expectedCodeLength
        self.correlationId = correlationId
        self.expectedError = expectedError
    }

    public func onSignInStartError(error: SignInStartError) {
        XCTAssertEqual(error.type, expectedError?.type)
        XCTAssertEqual(error.localizedDescription, expectedError?.localizedDescription)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    public func onSignInCodeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        newSignInCodeRequiredState = newState
        XCTAssertEqual(sentTo, expectedSentTo)
        XCTAssertEqual(channelTargetType, expectedChannelTargetType)
        XCTAssertEqual(codeLength, expectedCodeLength)
        XCTAssertTrue(Thread.isMainThread)
        if let verifyCodeDelegate = verifyCodeDelegate {
            newState.submitCode(code: "code", delegate: verifyCodeDelegate)
        } else {
            expectation.fulfill()
        }
    }
}

class SignInResendCodeDelegateSpy: SignInResendCodeDelegate {

    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    private(set) var newSignInResendCodeError: ResendCodeError?
    let expectation: XCTestExpectation
    var expectedSentTo: String?
    var expectedChannelTargetType: MSALNativeAuthChannelType?
    var expectedCodeLength: Int?

    init(expectation: XCTestExpectation, expectedSentTo: String? = nil, expectedChannelTargetType: MSALNativeAuthChannelType? = nil, expectedCodeLength: Int? = nil) {
        self.expectation = expectation
        self.expectedSentTo = expectedSentTo
        self.expectedChannelTargetType = expectedChannelTargetType
        self.expectedCodeLength = expectedCodeLength
    }

    func onSignInResendCodeError(error: ResendCodeError, newState: SignInCodeRequiredState?) {
        newSignInCodeRequiredState = newState
        newSignInResendCodeError = error
        expectation.fulfill()
    }

    func onSignInResendCodeCodeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        XCTAssertEqual(sentTo, expectedSentTo)
        XCTAssertEqual(channelTargetType, expectedChannelTargetType)
        XCTAssertEqual(codeLength, expectedCodeLength)
        XCTAssertTrue(Thread.isMainThread)
        newSignInCodeRequiredState = newState
        expectation.fulfill()
    }
}

class SignInResendCodeDelegateOptionalMethodsNotImplemented: SignInResendCodeDelegate {

    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    private(set) var newSignInResendCodeError: ResendCodeError?
    let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignInResendCodeError(error: ResendCodeError, newState: SignInCodeRequiredState?) {
        newSignInCodeRequiredState = newState
        newSignInResendCodeError = error
        expectation.fulfill()
    }
}

class SignInCodeStartDelegateWithPasswordRequiredSpy: SignInCodeStartDelegateSpy {
    var passwordRequiredState: SignInPasswordRequiredState?

    public func onSignInPasswordRequired(newState: SignInPasswordRequiredState) {
        passwordRequiredState = newState
        expectation.fulfill()
    }
}

open class SignInVerifyCodeDelegateSpy: SignInVerifyCodeDelegate {

    private let expectation: XCTestExpectation
    var expectedError: VerifyCodeError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    var expectedNewState: SignInCodeRequiredState?
    private(set) var onSignInCompletedCalled: Bool = false
    
    init(expectation: XCTestExpectation, expectedError: VerifyCodeError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    public func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?) {
        XCTAssertEqual(error.type, expectedError?.type)
        if let expectedNewState {
            XCTAssertEqual(newState, expectedNewState)
        }
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        guard let expectedUserAccountResult = expectedUserAccountResult else {
            XCTFail("expectedUserAccountResult expected not nil")
            expectation.fulfill()
            return
        }
        XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

final class SignInVerifyCodeDelegateOptionalMethodsNotImplemented: SignInVerifyCodeDelegate {

    private let expectation: XCTestExpectation
    var expectedError: VerifyCodeError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    var expectedNewState: SignInCodeRequiredState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    public func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?) {
        expectedError = error
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

open class SignInAfterSignUpDelegateSpy: SignInAfterSignUpDelegate {

    private let expectation: XCTestExpectation
    var expectedError: SignInAfterSignUpError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    private(set) var onSignInCompletedCalled = false
    
    init(expectation: XCTestExpectation, expectedError: SignInAfterSignUpError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    public func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        checkErrors(error: error, expectedError: expectedError)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        guard let expectedUserAccountResult = expectedUserAccountResult else {
            XCTFail("expectedUserAccount expected not nil")
            expectation.fulfill()
            return
        }
        XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

class SignInAfterResetPasswordDelegateSpy: SignInAfterResetPasswordDelegate {
    private let expectation: XCTestExpectation
    var expectedError: SignInAfterResetPasswordError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    private(set) var onSignInCompletedCalled = false

    init(expectation: XCTestExpectation, expectedError: SignInAfterResetPasswordError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    func onSignInAfterResetPasswordError(error: SignInAfterResetPasswordError) {
        checkErrors(error: error, expectedError: expectedError)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        guard let expectedUserAccountResult = expectedUserAccountResult else {
            XCTFail("expectedUserAccount expected not nil")
            expectation.fulfill()
            return
        }
        XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

final class SignInAfterSignUpDelegateOptionalMethodsNotImplemented: SignInAfterSignUpDelegate {

    private let expectation: XCTestExpectation
    var expectedError: SignInAfterSignUpError?

    init(expectation: XCTestExpectation, expectedError: SignInAfterSignUpError? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
    }

    public func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        checkErrors(error: error, expectedError: expectedError)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

final class SignInPasswordStartDelegateOptionalMethodNotImplemented: SignInStartDelegate {
    private let expectation: XCTestExpectation
    var expectedError: SignInStartError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?

    init(expectation: XCTestExpectation, expectedError: SignInStartError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    func onSignInStartError(error: MSAL.SignInStartError) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            checkErrors(error: error, expectedError: expectedError)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
}

final class SignInCodeStartDelegateOptionalMethodNotImplemented: SignInStartDelegate {

    let expectation: XCTestExpectation
    var expectedError: SignInStartError?

    init(expectation: XCTestExpectation, expectedError: SignInStartError) {
        self.expectation = expectation
        self.expectedError = expectedError
    }

    public func onSignInStartError(error: SignInStartError) {
        checkErrors(error: error, expectedError: expectedError)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

fileprivate func checkErrors(error: SignInStartError, expectedError: SignInStartError?) {
    XCTAssertEqual(error.type, expectedError?.type)
    XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
    XCTAssertEqual(error.errorCodes, expectedError?.errorCodes)
    XCTAssertEqual(error.errorUri, expectedError?.errorUri)
    XCTAssertEqual(error.correlationId, expectedError?.correlationId)
}

fileprivate func checkErrors(error: PasswordRequiredError, expectedError: PasswordRequiredError?) {
    XCTAssertEqual(error.type, expectedError?.type)
    XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
    XCTAssertEqual(error.errorCodes, expectedError?.errorCodes)
    XCTAssertEqual(error.errorUri, expectedError?.errorUri)
    XCTAssertEqual(error.correlationId, expectedError?.correlationId)
}

fileprivate func checkErrors(error: SignInAfterSignUpError, expectedError: SignInAfterSignUpError?) {
    XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
    XCTAssertEqual(error.errorCodes, expectedError?.errorCodes)
    XCTAssertEqual(error.errorUri, expectedError?.errorUri)
    XCTAssertEqual(error.correlationId, expectedError?.correlationId)
}

fileprivate func checkErrors(error: SignInAfterResetPasswordError, expectedError: SignInAfterResetPasswordError?) {
    XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
    XCTAssertEqual(error.errorCodes, expectedError?.errorCodes)
    XCTAssertEqual(error.errorUri, expectedError?.errorUri)
    XCTAssertEqual(error.correlationId, expectedError?.correlationId)
}
