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

import Foundation
import XCTest
import MSAL

final class MSALNativeAuthSignUpUsernameV2EndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("Sign Up V2 requires a test slice. Disable this test until api/test slice is ready.")
    }

    // Hero Scenario 2.1.1. Sign up – with Email Verification (Email & Email OTP)
    @MainActor
    func test_signUpWithCode_withEmailVerification_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let password = generateRandomPassword()
        let usernameOTP = await createEmailProviderAccount(password: password)
        guard !usernameOTP.isEmpty else {
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: usernameOTP)
        parameters.correlationId = correlationId

        markEmailCheckpoint()
        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code = await retrieveCodeFor(email: usernameOTP, password: password) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        let signInAfterSignUpRequiredExp = expectation(description: "sign in after sign up required")
        delegate.reset(expectation: signInAfterSignUpRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [signInAfterSignUpRequiredExp])

        guard delegate.onSignInAfterSignUpRequiredCalled,
              let signInAfterSignUpState = delegate.signInAfterSignUpState
        else {
            XCTFail("onSignInAfterSignUpRequired not called")
            return
        }

        try await continueSignInAfterSignUp(
            state: signInAfterSignUpState,
            delegate: delegate,
            username: usernameOTP
        )
    }

    // Hero Scenario 2.1.2. Sign up – with Email Verification as LAST step & Custom Attributes (Email & Email OTP)
    @MainActor
    func test_signUpWithCode_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .codeAndAttributes,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let password = generateRandomPassword()
        let usernameOTP = await createEmailProviderAccount(password: password)
        guard !usernameOTP.isEmpty else {
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: usernameOTP)
        parameters.attributes = AttributesStub.allAttributes
        parameters.correlationId = correlationId

        markEmailCheckpoint()
        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code = await retrieveCodeFor(email: usernameOTP, password: password) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        let signInAfterSignUpRequiredExp = expectation(description: "sign in after sign up required")
        delegate.reset(expectation: signInAfterSignUpRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [signInAfterSignUpRequiredExp])

        guard delegate.onSignInAfterSignUpRequiredCalled,
              let signInAfterSignUpState = delegate.signInAfterSignUpState
        else {
            XCTFail("onSignInAfterSignUpRequired not called")
            return
        }

        try await continueSignInAfterSignUp(
            state: signInAfterSignUpState,
            delegate: delegate,
            username: usernameOTP
        )
    }

    // Hero Scenario 2.1.3. Sign up – with Email Verification as FIRST step & Custom Attributes (Email & Email OTP)
    @MainActor
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .codeAndAttributes,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let password = generateRandomPassword()
        let usernameOTP = await createEmailProviderAccount(password: password)
        guard !usernameOTP.isEmpty else {
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: usernameOTP)
        parameters.correlationId = correlationId

        markEmailCheckpoint()
        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code = await retrieveCodeFor(email: usernameOTP, password: password) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        let attributesRequiredExp = expectation(description: "attributes required")
        delegate.reset(expectation: attributesRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [attributesRequiredExp])

        guard delegate.onAttributesRequiredCalled,
              let attributesRequiredState = delegate.attributesRequiredState
        else {
            XCTFail("onAttributesRequired not called")
            return
        }
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertFalse(attributesRequiredState.attributes.isEmpty)

        let signInAfterSignUpRequiredExp = expectation(description: "sign in after sign up required")
        delegate.reset(expectation: signInAfterSignUpRequiredExp)
        attributesRequiredState.submitAttributes(AttributesStub.allAttributes, delegate: delegate)

        await fulfillment(of: [signInAfterSignUpRequiredExp])

        guard delegate.onSignInAfterSignUpRequiredCalled,
              let signInAfterSignUpState = delegate.signInAfterSignUpState
        else {
            XCTFail("onSignInAfterSignUpRequired not called")
            return
        }

        try await continueSignInAfterSignUp(
            state: signInAfterSignUpState,
            delegate: delegate,
            username: usernameOTP
        )
    }

    // Hero Scenario 2.1.4. Sign up – with Email Verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Email OTP)
    @MainActor
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .codeAndAttributes,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let password = generateRandomPassword()
        let usernameOTP = await createEmailProviderAccount(password: password)
        guard !usernameOTP.isEmpty else {
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: usernameOTP)
        parameters.correlationId = correlationId

        markEmailCheckpoint()
        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code = await retrieveCodeFor(email: usernameOTP, password: password) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        let firstAttributesExp = expectation(description: "first attributes step")
        delegate.reset(expectation: firstAttributesExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [firstAttributesExp])

        guard delegate.onAttributesRequiredCalled,
              let firstAttributesState = delegate.attributesRequiredState
        else {
            XCTFail("onAttributesRequired not called")
            return
        }

        let secondAttributesExp = expectation(description: "second attributes step")
        delegate.reset(expectation: secondAttributesExp)
        firstAttributesState.submitAttributes(AttributesStub.attribute1, delegate: delegate)

        await fulfillment(of: [secondAttributesExp])

        let secondAttributesState = delegate.attributesRequiredState
        let invalidAttributesState = delegate.attributesInvalidState
        let finalSubmitExp = expectation(description: "final attributes submission")
        delegate.reset(expectation: finalSubmitExp)

        if let secondAttributesState = secondAttributesState {
            secondAttributesState.submitAttributes(AttributesStub.attribute2, delegate: delegate)
        } else if let invalidAttributesState = invalidAttributesState {
            invalidAttributesState.submitAttributes(AttributesStub.attribute2, delegate: delegate)
        } else {
            XCTFail("Expected another attributes continuation")
            return
        }

        await fulfillment(of: [finalSubmitExp])

        guard delegate.onSignInAfterSignUpRequiredCalled,
              let signInAfterSignUpState = delegate.signInAfterSignUpState
        else {
            XCTFail("onSignInAfterSignUpRequired not called")
            return
        }

        try await continueSignInAfterSignUp(
            state: signInAfterSignUpState,
            delegate: delegate,
            username: usernameOTP
        )
    }

    // use case 2.1.5. Sign up - with Email & OTP resend email OTP
    @MainActor
    func test_signUpWithEmailOTP_resendEmail_success() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let password = generateRandomPassword()
        let username = await createEmailProviderAccount(password: password)
        guard !username.isEmpty else {
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: username)
        parameters.correlationId = correlationId

        markEmailCheckpoint()
        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code1 = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let resendCodeRequiredExp = expectation(description: "code required again")
        delegate.reset(expectation: resendCodeRequiredExp)

        markEmailCheckpoint()
        codeRequiredState.resendCode(delegate: delegate)

        await fulfillment(of: [resendCodeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled else {
            XCTFail("Resend code method should have been called")
            return
        }

        guard let code2 = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        XCTAssertNotEqual(code1, code2, "Resent code should be different from the original code")
    }

    // use case 2.1.6. Sign Up - with Email & OTP, User already exists with given email as email-otp account
    @MainActor
    func test_signUpWithEmailOTP_andExistingAccount() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }

        let signUpFailureExp = expectation(description: "sign-up with existing email fails")
        let delegate = SignUpV2DelegateSpy(expectation: signUpFailureExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: username)
        parameters.correlationId = correlationId

        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [signUpFailureExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertEqual(delegate.error?.isUserAlreadyExists, true)
    }

    // Use case 2.1.7. Sign up - with Email & Password, User already exists with given email as social account
    @MainActor
    func test_signUpWithEmailPassword_socialAccount_fails() async throws {
        throw XCTSkip("Skipping test as it requires a Social account, not present in MSIDLAB")
    }

    // Use case 2.1.8. Sign up - with Email & OTP, Developer makes a request with invalid format email address
    @MainActor
    func test_signUpWithEmailPassword_invalidEmailFormat_fails() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let signUpFailureExp = expectation(description: "sign-up with invalid email format fails")
        let delegate = SignUpV2DelegateSpy(expectation: signUpFailureExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: "invalid")
        parameters.correlationId = correlationId

        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [signUpFailureExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertEqual(delegate.error?.isInvalidUsername, true)
    }

    // Hero Scenario 2.1.9. Sign up – without automatic sign in (Email & Email OTP)
    @MainActor
    func test_signUpWithoutAutomaticSignIn() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let password = generateRandomPassword()
        let usernameOTP = await createEmailProviderAccount(password: password)
        guard !usernameOTP.isEmpty else {
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: usernameOTP)
        parameters.correlationId = correlationId

        markEmailCheckpoint()
        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code = await retrieveCodeFor(email: usernameOTP, password: password) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        let signInAfterSignUpRequiredExp = expectation(description: "sign in after sign up required")
        delegate.reset(expectation: signInAfterSignUpRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [signInAfterSignUpRequiredExp])

        XCTAssertTrue(delegate.onSignInAfterSignUpRequiredCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertNotNil(delegate.signInAfterSignUpState)
        XCTAssertFalse(delegate.onFlowCompletedCalled)
    }

    // Use case 2.1.10 Sign up - with Email & Password, Server requires password
    // authentication, which is not supported by the developer (aka redirect flow)
    @MainActor
    func test_signUpWithEmailPassword_butChallengeTypeOOB_fails() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
            challengeTypes: [.OOB],
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let signUpFailureExp = expectation(description: "sign-up with invalid challenge type fails")
        let delegate = SignUpV2DelegateSpy(expectation: signUpFailureExp)
        let parameters = MSALNativeAuthSignUpParametersV2(username: generateSignUpRandomEmail())
        parameters.password = generateRandomPassword()
        parameters.correlationId = correlationId

        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [signUpFailureExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertEqual(delegate.error?.isBrowserRequired, true)
    }

    @MainActor
    private func checkCodeRequired(_ delegate: SignUpV2DelegateSpy) {
        let scenario = delegate.scenario
        let isEmailType = delegate.channelTargetType?.isEmailType
        let isSentToEmpty = delegate.sentTo?.isEmpty
        let codeLength = delegate.codeLength

        XCTAssertEqual(scenario, .signUp)
        XCTAssertEqual(isEmailType, true)
        XCTAssertFalse(isSentToEmpty ?? true)
        XCTAssertGreaterThan(codeLength, 0)
    }

    @MainActor
    private func continueSignInAfterSignUp(
        state: MSALNativeAuthSignInAfterSignUpState,
        delegate: SignUpV2DelegateSpy,
        username: String
    ) async throws {
        let flowCompletedExp = expectation(description: "sign in after sign up completed")
        delegate.reset(expectation: flowCompletedExp)

        let parameters = MSALNativeAuthSignInAfterSignUpParameters()
        state.signIn(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertEqual(delegate.result?.account.username?.lowercased(), username.lowercased())
    }
}
