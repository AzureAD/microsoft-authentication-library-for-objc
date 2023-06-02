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
    var expectedUserAccount: MSALNativeAuthUserAccount?
    
    init(expectation: XCTestExpectation, expectedError: SignInPasswordStartError? = nil, expectedUserAccount: MSALNativeAuthUserAccount? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccount = expectedUserAccount
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
    
    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        if let expectedUserAccount = expectedUserAccount {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(expectedUserAccount.accessToken, result.accessToken)
            XCTAssertEqual(expectedUserAccount.rawIdToken, result.rawIdToken)
            XCTAssertEqual(expectedUserAccount.scopes, result.scopes)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
}

class SignInPasswordRequiredDelegateSpy: SignInPasswordRequiredDelegate {

    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: SignInPasswordRequiredState?
    private(set) var newSignInCodeRequiredState: SignInCodeRequiredState?
    private(set) var signInCompletedCalled = false

    func onSignInPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignInPasswordRequiredState?) {
        self.error = error
        newPasswordRequiredState = newState
    }

    func onSignInCodeRequired(newState: SignInCodeRequiredState,
                              sentTo: String,
                              channelTargetType: MSALNativeAuthChannelType,
                              codeLength: Int) {
        newSignInCodeRequiredState = newState
    }

    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        signInCompletedCalled = true
    }
}

open class SignInPasswordStartDelegateFailureSpy: SignInPasswordStartDelegate {

    public func onSignInPasswordError(error: MSAL.SignInPasswordStartError) {
        XCTFail("This method should not be called")
    }
    
    public func onSignInCodeRequired(newState: MSAL.SignInCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        XCTFail("This method should not be called")
    }
    
    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        XCTFail("This method should not be called")
    }
}

open class SignInCodeStartDelegateSpy: SignInCodeStartDelegate {
    
    private let expectation: XCTestExpectation
    var expectedError: SignInCodeStartError?
    var expectedSentTo: String?
    var expectedChannelTargetType: MSALNativeAuthChannelType?
    var expectedCodeLength: Int?
    var verifyCodeDelegate: SignInVerifyCodeDelegate?
    var correlationId: UUID?
    
    init(expectation: XCTestExpectation, correlationId: UUID? = nil, verifyCodeDelegate: SignInVerifyCodeDelegate? = nil, expectedError: SignInCodeStartError? = nil, expectedSentTo: String? = nil, expectedChannelTargetType: MSALNativeAuthChannelType? = nil, expectedCodeLength: Int? = nil) {
        self.expectation = expectation
        self.verifyCodeDelegate = verifyCodeDelegate
        self.expectedSentTo = expectedSentTo
        self.expectedChannelTargetType = expectedChannelTargetType
        self.expectedCodeLength = expectedCodeLength
        self.correlationId = correlationId
        self.expectedError = expectedError
    }
    
    public func onSignInCodeError(error: SignInCodeStartError) {
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

open class SignInVerifyCodeDelegateSpy: SignInVerifyCodeDelegate {
    
    private let expectation: XCTestExpectation
    var expectedError: VerifyCodeError?
    var expectedUserAccount: MSALNativeAuthUserAccount?
    
    init(expectation: XCTestExpectation, expectedError: VerifyCodeError? = nil, expectedUserAccount: MSALNativeAuthUserAccount? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedUserAccount = expectedUserAccount
    }
    
    public func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?) {
        XCTAssertEqual(error, expectedError)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
    
    public func onSignInCompleted(result: MSALNativeAuthUserAccount) {
        guard let expectedUserAccount = expectedUserAccount else {
            XCTFail("expectedUserAccount expected not nil")
            expectation.fulfill()
            return
        }
        XCTAssertEqual(expectedUserAccount.accessToken, result.accessToken)
        XCTAssertEqual(expectedUserAccount.rawIdToken, result.rawIdToken)
        XCTAssertEqual(expectedUserAccount.scopes, result.scopes)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}
