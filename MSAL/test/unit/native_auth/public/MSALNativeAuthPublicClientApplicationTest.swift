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
    
    private class SignInPasswordStartCompletionErrorDelegate: SignInPasswordStartDelegate, SignInStartDelegate {
        var expectedErrorType = SignInPasswordStartErrorType.invalidUsername
        var expectedOTPErrorType = SignInStartErrorType.invalidUsername
        
        func onSignInPasswordError(error: MSAL.SignInPasswordStartError) {
            XCTAssertEqual(error.type, expectedErrorType)
            expectation.fulfill()
        }
        
        func onSignInError(error: MSAL.SignInStartError) {
            XCTAssertEqual(error.type, expectedOTPErrorType)
            expectation.fulfill()
        }
        
        func onSignInCodeRequired(newState: MSAL.SignInCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
        func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
            XCTFail()
            expectation.fulfill()
        }
    }
    
    private class SignUpStartCompletionErrorDelegate: SignUpPasswordStartDelegate, SignUpStartDelegate {
        var expectedErrorType = SignUpPasswordStartErrorType.invalidUsername
        var expectedOTPErrorType = SignUpStartErrorType.invalidUsername
        
        func onSignUpPasswordError(error: MSAL.SignUpPasswordStartError) {
            XCTAssertEqual(error.type, expectedErrorType)
            expectation.fulfill()
        }
        
        func onSignUpError(error: MSAL.SignUpStartError) {
            XCTAssertEqual(error.type, expectedOTPErrorType)
            expectation.fulfill()
        }
        
        func onSignUpCodeRequired(newState: MSAL.SignUpCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
        func completed(result: MSAL.MSALNativeAuthUserAccountResult) {
            XCTFail()
            expectation.fulfill()
        }
    }
    
    private class ResetPasswordStartCompletionErrorDelegate: ResetPasswordStartDelegate {
        func onResetPasswordError(error: MSAL.ResetPasswordStartError) {
            XCTAssertEqual(error.type, ResetPasswordStartErrorType.invalidUsername)
            expectation.fulfill()
        }
        
        func onResetPasswordCodeRequired(newState: MSAL.ResetPasswordCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
            XCTFail()
            expectation.fulfill()
        }
        
    }

    func testInit_whenPassingB2CAuthority_itShouldThrowError() throws {
        let b2cAuthority = try MSALB2CAuthority(url: .init(string: "https://login.contoso.com")!)
        let configuration = MSALPublicClientApplicationConfig(clientId: DEFAULT_TEST_CLIENT_ID, redirectUri: nil, authority: b2cAuthority)

        XCTAssertThrowsError(try MSALNativeAuthPublicClientApplication(configuration: configuration, challengeTypes: [.password]))
    }
    
    func testInit_whenPassingNilRedirectUri_itShouldNotThrowError() {
        XCTAssertNoThrow(try MSALNativeAuthPublicClientApplication(clientId: "genericClient", tenantSubdomain: "genericTenenat", challengeTypes: [.OOB]))
    }
    
    func testSignIn_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.signInUsingPassword(username: "", password: "", delegate: SignInPasswordStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignIn_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let delegate = SignInPasswordStartCompletionErrorDelegate()
        delegate.expectedErrorType = .invalidPassword
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.signInUsingPassword(username: "correct", password: "", delegate: delegate)
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignInOTP_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.signIn(username: "", delegate: SignInPasswordStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignUp_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.signUpUsingPassword(username: "", password: "", delegate: SignUpStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignUp_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let delegate = SignUpStartCompletionErrorDelegate()
        delegate.expectedErrorType = .invalidPassword
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.signUpUsingPassword(username: "correct", password: "", delegate: delegate)
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testSignUpOTP_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.signUp(username: "", delegate: SignUpStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
    func testResetPassword_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        MSALNativeAuthPublicClientApplicationTest.expectation = XCTestExpectation()
        let application = MSALNativeAuthPublicClientApplication(controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidator(), internalChallengeTypes: [])
        application.resetPassword(username: "", delegate: ResetPasswordStartCompletionErrorDelegate())
        wait(for: [MSALNativeAuthPublicClientApplicationTest.expectation], timeout: 1)
    }
    
}
