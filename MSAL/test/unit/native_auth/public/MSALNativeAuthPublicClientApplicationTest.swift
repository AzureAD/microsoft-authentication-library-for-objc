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
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthPublicClientApplicationTest: XCTestCase {

    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private var sut: MSALNativeAuthPublicClientApplication!

    override func setUp() {
        super.setUp()

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
    }

    func testInit_whenPassingB2CAuthority_itShouldThrowError() throws {
        let b2cAuthority = try MSALB2CAuthority(url: .init(string: "https://login.contoso.com")!)
        let configuration = MSALPublicClientApplicationConfig(clientId: DEFAULT_TEST_CLIENT_ID, redirectUri: nil, authority: b2cAuthority)

        XCTAssertThrowsError(try MSALNativeAuthPublicClientApplication(configuration: configuration, challengeTypes: [.password]))
    }

    func testInit_whenPassingNilRedirectUri_itShouldNotThrowError() {
        XCTAssertNoThrow(try MSALNativeAuthPublicClientApplication(clientId: "genericClient", tenantSubdomain: "genericTenenat", challengeTypes: [.OOB]))
    }

    // MARK: - Delegates

    // Sign Up with password

    func testSignUpPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        sut.signUpUsingPassword(username: "", password: "", delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUpPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        sut.signUpUsingPassword(username: "correct", password: "", delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
    }

    func testSignUpPassword_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)

        let expectedResult: SignUpPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken"),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult)

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp])

        XCTAssertEqual(delegate.newState?.continuationToken, "flowToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testSignUpPassword_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpPasswordStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult)

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUpPassword_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpPasswordStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult)

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.codeRequiredNotImplemented)
    }

    // Sign Up with code

    func testSignUp_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        sut.signUp(username: "", delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUp_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken"),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult)

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp])

        XCTAssertEqual(delegate.newState?.continuationToken, "flowToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testSignUp_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult)

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUp_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult)

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.codeRequiredNotImplemented)
    }

    // Sign in with password

    func testSignInPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername))
        sut.signInUsingPassword(username: "", password: "", delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func testSignInPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidPassword))
        sut.signInUsingPassword(username: "correct", password: "", delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignInPassword_delegate_whenValidUserAndPasswordAreUsed_shouldReturnSuccess() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedUserAccountResult: MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInPasswordStartResult = .init(.init(.completed(MSALNativeAuthUserAccountResultStub.result)))
        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [expectation], timeout: 1)
    }

    func testSignInPassword_delegate_whenCodeIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = .email

        let expectedResult: SignInPasswordStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: ""),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        
        controllerFactoryMock.signInController.signInPasswordStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenCodeIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.codeRequiredNotImplemented)
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInPasswordStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: ""),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInPasswordStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // Sign in with code

    func testSignIn_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername))
        sut.signIn(username: "", delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignIn_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInCodeStartDelegateSpy(expectation: expectation)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = .email

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: ""),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult)
        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [expectation], timeout: 1)
    }

    func testSignIn_delegate_whenPasswordIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnPasswordRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInCodeStartDelegateWithPasswordRequiredSpy(expectation: exp1)

        let expectedState = SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, flowToken: "flowToken")
        let expectedResult: SignInStartResult = .passwordRequired(newState: expectedState)

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.passwordRequiredState?.continuationToken, expectedState.continuationToken)
    }

    func testSignIn_delegate_whenPasswordIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.passwordRequiredNotImplemented)
        let delegate = SignInCodeStartDelegateSpy(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .passwordRequired(
            newState: SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, flowToken: "")
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // ResetPassword

    func testResetPassword_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-in public interface")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp)
        sut.resetPassword(username: "", delegate: delegate)
        wait(for: [exp])
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testResetPassword_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = ResetPasswordStartDelegateSpy(expectation: expectation)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, flowToken: "flowToken"),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.resetPasswordController.resetPasswordResult = .init(expectedResult)
        sut.resetPassword(username: "correct", delegate: delegate)

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(delegate.newState?.continuationToken, "flowToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }
}
