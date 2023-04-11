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

import Foundation

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

final class MSALNativeAuthPublicClientApplicationTest: XCTestCase {
    
    private static var expectation = XCTestExpectation()
    
    private class SignInStartCompletionErrorDelegate: SignInStartDelegate {
        var expectedErrorType = SignInStartErrorType.invalidUsername
        
        func signInFlowInterrupted(reason: MSAL.SignInStartFlowInterruptionReason) {
            XCTFail()
            expectation.fulfill()
        }
        
        func onError(error: MSAL.SignInStartError) {
            XCTAssertEqual(error.type, expectedErrorType)
            expectation.fulfill()
        }
        
        func onCodeSent(state: MSAL.SignInCodeSentState, displayName: String, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
        func completed(result: MSAL.MSALNativeAuthUserAccount) {
            XCTFail()
            expectation.fulfill()
        }
    }
    
    private class SignUpStartCompletionErrorDelegate: SignUpStartDelegate {
        
        var expectedErrorType = SignUpStartErrorType.invalidUsername
        
        func onError(error: MSAL.SignUpStartError) {
            XCTAssertEqual(error.type, expectedErrorType)
            expectation.fulfill()
        }
        
        func onCodeSent(state: MSAL.SignUpCodeSentState, displayName: String, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
        func onCodeSent(state: MSAL.SignInCodeSentState, displayName: String, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
        func completed(result: MSAL.MSALNativeAuthUserAccount) {
            XCTFail()
            expectation.fulfill()
        }
        
        func signUpFlowInterrupted(reason: MSAL.SignUpStartFlowInterruptionReason) {
            XCTFail()
            expectation.fulfill()
        }
    }
    
    private class ResetPasswordStartCompletionErrorDelegate: ResetPasswordStartDelegate {
                
        func resetPasswordFlowInterrupted(reason: MSAL.ResetPasswordStartFlowInterruptionReason) {
            XCTFail()
            expectation.fulfill()
        }
        
        func onError(error: MSAL.ResetPasswordStartError) {
            XCTAssertEqual(error.type, ResetPasswordStartErrorType.invalidUsername)
            expectation.fulfill()
        }
        
        func onCodeSent(state: MSAL.CodeSentResetPasswordState, displayName: String, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
    }

    func testInit_whenPassingB2CAuthority_itShouldThrowError() throws {
        let b2cAuthority = try MSALB2CAuthority(url: .init(string: "https://login.contoso.com")!)
        let configuration = MSALPublicClientApplicationConfig(clientId: DEFAULT_TEST_CLIENT_ID, redirectUri: nil, authority: b2cAuthority)

        XCTAssertThrowsError(try MSALNativeAuthPublicClientApplication(configuration: configuration, challengeTypes: [.password]))
    }
    
    func testSignIn_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator())
        application.signIn(username: "", password: nil, delegate: SignInStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignIn_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let delegate = SignInStartCompletionErrorDelegate()
        delegate.expectedErrorType = .passwordInvalid
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator())
        application.signIn(username: "correct", password: "", delegate: delegate)
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignUp_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator())
        application.signUp(username: "", password: nil, delegate: SignUpStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignUp_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let delegate = SignUpStartCompletionErrorDelegate()
        delegate.expectedErrorType = .passwordInvalid
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator())
        application.signUp(username: "correct", password: "", delegate: delegate)
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testResetPassword_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator())
        application.resetPassword(username: "", delegate: ResetPasswordStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
}
