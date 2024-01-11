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
import MSAL

final class MSALNativeAuthSignUpUsernameEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    private let usernameOTP = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"
    private let attributes = ["age": 40]

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(!usingMockAPI)
    }

    // Hero Scenario 1.1.1. Sign up – with Email Verification (Email & Email OTP)
    func test_signUpWithCode_withEmailVerification_succeeds() async throws {
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.signUpStartSuccess, endpoint: .signUpStart)
            try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        }

        sut.signUp(username: usernameOTP, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        if usingMockAPI {
            try await mockResponse(.signUpContinueSuccess, endpoint: .signUpContinue)
        }

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 1.1.2. Sign up – with Email Verification as LAST step & Custom Attributes (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.signUpStartSuccess, endpoint: .signUpStart)
            try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        }

        sut.signUp(username: usernameOTP, attributes: attributes, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        if usingMockAPI {
            try await mockResponse(.signUpContinueSuccess, endpoint: .signUpContinue)
        }

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 1.1.3. Sign up – with Email Verification as FIRST step & Custom Attributes (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.signUpStartSuccess, endpoint: .signUpStart)
            try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        }

        sut.signUp(username: usernameOTP, attributes: attributes, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let submitCodeExp = expectation(description: "submit code")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)

        if usingMockAPI {
            try await mockResponse(.attributesRequired, endpoint: .signUpContinue)
        }

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let attributesExp = expectation(description: "submit attributes, sign-up complete")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesExp)

        if usingMockAPI {
            try await mockResponse(.signUpContinueSuccess, endpoint: .signUpContinue)
        }

        signUpVerifyCodeDelegate.attributesRequiredNewState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 1.1.4. Sign up – with Email Verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsLastStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.signUpStartSuccess, endpoint: .signUpStart)
            try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        }

        sut.signUp(username: usernameOTP, attributes: attributes, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let submitCodeExp = expectation(description: "submit code")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)

        if usingMockAPI {
            try await mockResponse(.attributesRequired, endpoint: .signUpContinue)
        }

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let submitAttributesExp1 = expectation(description: "submit attributes 1")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: submitAttributesExp1)

        if usingMockAPI {
            try await mockResponse(.attributesRequired, endpoint: .signUpContinue)
        }

        signUpVerifyCodeDelegate.attributesRequiredNewState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [submitAttributesExp1], timeout: defaultTimeout)
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpAttributesRequiredErrorCalled)

        // Now submit more attributes...

        let submitAttributesExp2 = expectation(description: "submit attributes 2, sign-up complete")
        signUpAttributesRequiredDelegate.expectation = submitAttributesExp2

        if usingMockAPI {
            try await mockResponse(.signUpContinueSuccess, endpoint: .signUpContinue)
        }

        signUpAttributesRequiredDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [submitAttributesExp2], timeout: defaultTimeout)
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 1.1.5. Sign up – without automatic sign in (Email & Email OTP)
    func test_signUpWithoutAutomaticSignIn() async throws {
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.signUpStartSuccess, endpoint: .signUpStart)
            try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        }

        sut.signUp(username: usernameOTP, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        if usingMockAPI {
            try await mockResponse(.signUpContinueSuccess, endpoint: .signUpContinue)
        }

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)
    }

    private func checkSignUpStartDelegate(_ delegate: SignUpStartDelegateSpy) {
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)
    }

    private func checkSignInAfterSignUpDelegate(_ delegate: SignInAfterSignUpDelegateSpy) {
        XCTAssertTrue(delegate.onSignInCompletedCalled)
        XCTAssertEqual(delegate.result?.account.username, usernameOTP)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertNil(delegate.result?.account.accountClaims)
        XCTAssertEqual(delegate.result?.scopes[0], "openid")
        XCTAssertEqual(delegate.result?.scopes[1], "offline_access")
    }
}
