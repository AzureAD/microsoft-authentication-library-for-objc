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

open class SignInPasswordStartDelegateSpy: SignInPasswordStartDelegate {
    private let expectation: XCTestExpectation
    var expectedError: SignInPasswordStartError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    
    init(expectation: XCTestExpectation, expectedError: SignInPasswordStartError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }
    
    public func onSignInPasswordError(error: MSAL.SignInPasswordStartError) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(error.type, expectedError.type)
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
    
    public func onSignInCodeRequired(newState: MSAL.SignInCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
    
    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        if let expectedUserAccountResult = expectedUserAccountResult {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
            XCTAssertEqual(expectedUserAccountResult.scopes, result.scopes)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }
}

class SignInPasswordRequiredDelegateSpy: SignInPasswordRequiredDelegate {

    private(set) var newPasswordRequiredState: SignInPasswordRequiredState?
    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    fileprivate let expectation: XCTestExpectation
    var expectedError: PasswordRequiredError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    
    init(expectation: XCTestExpectation, expectedError: PasswordRequiredError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }

    func onSignInPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignInPasswordRequiredState?) {
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual(error.type, expectedError?.type)
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
            XCTAssertEqual(expectedUserAccountResult.scopes, result.scopes)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }
}

open class SignInPasswordStartDelegateFailureSpy: SignInPasswordStartDelegate {

    public func onSignInPasswordError(error: MSAL.SignInPasswordStartError) {
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
    
    fileprivate let expectation: XCTestExpectation
    var expectedError: SignInStartError?
    var expectedSentTo: String?
    var expectedChannelTargetType: MSALNativeAuthChannelType?
    var expectedCodeLength: Int?
    var verifyCodeDelegate: SignInVerifyCodeDelegate?
    var correlationId: UUID?
    
    init(expectation: XCTestExpectation, correlationId: UUID? = nil, verifyCodeDelegate: SignInVerifyCodeDelegate? = nil, expectedError: SignInStartError? = nil, expectedSentTo: String? = nil, expectedChannelTargetType: MSALNativeAuthChannelType? = nil, expectedCodeLength: Int? = nil) {
        self.expectation = expectation
        self.verifyCodeDelegate = verifyCodeDelegate
        self.expectedSentTo = expectedSentTo
        self.expectedChannelTargetType = expectedChannelTargetType
        self.expectedCodeLength = expectedCodeLength
        self.correlationId = correlationId
        self.expectedError = expectedError
    }
    
    public func onSignInError(error: SignInStartError) {
        XCTAssertEqual(error.type, expectedError?.type)
        XCTAssertEqual(error.localizedDescription, expectedError?.localizedDescription)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
    
    public func onSignInCodeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        XCTAssertEqual(sentTo, expectedSentTo)
        XCTAssertEqual(channelTargetType, expectedChannelTargetType)
        XCTAssertEqual(codeLength, expectedCodeLength)
        XCTAssertTrue(Thread.isMainThread)
        if let verifyCodeDelegate = verifyCodeDelegate {
            newState.submitCode(code: "code", delegate: verifyCodeDelegate, correlationId: correlationId)
        } else {
            expectation.fulfill()
        }
    }
}

class SignInResendCodeDelegateSpy: SignInResendCodeDelegate {
    
    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    fileprivate let expectation: XCTestExpectation
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
        expectation.fulfill()
    }

    func onSignInResendCodeCodeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        XCTAssertEqual(sentTo, expectedSentTo)
        XCTAssertEqual(channelTargetType, expectedChannelTargetType)
        XCTAssertEqual(codeLength, expectedCodeLength)
        XCTAssertTrue(Thread.isMainThread)
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
    
    init(expectation: XCTestExpectation, expectedError: VerifyCodeError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }
    
    public func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?) {
        XCTAssertEqual(error.type, expectedError?.type)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
    
    public func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        guard let expectedUserAccountResult = expectedUserAccountResult else {
            XCTFail("expectedUserAccountResult expected not nil")
            expectation.fulfill()
            return
        }
        XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        XCTAssertEqual(expectedUserAccountResult.scopes, result.scopes)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}

open class SignInAfterSignUpDelegateSpy: SignInAfterSignUpDelegate {
    
    private let expectation: XCTestExpectation
    var expectedError: SignInAfterSignUpError?
    var expectedUserAccountResult: MSALNativeAuthUserAccountResult?
    
    init(expectation: XCTestExpectation, expectedError: SignInAfterSignUpError? = nil, expectedUserAccountResult: MSALNativeAuthUserAccountResult? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccountResult = expectedUserAccountResult
    }
    
    public func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
    
    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        guard let expectedUserAccountResult = expectedUserAccountResult else {
            XCTFail("expectedUserAccount expected not nil")
            expectation.fulfill()
            return
        }
        XCTAssertEqual(expectedUserAccountResult.idToken, result.idToken)
        XCTAssertEqual(expectedUserAccountResult.scopes, result.scopes)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}
