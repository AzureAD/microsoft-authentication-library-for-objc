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

final class MSALNativeAuthSignUpUsernameAndPasswordV2EndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    // Hero Scenario 1.1.1. Sign up - with Email verification as LAST step (Email & Password)
    @MainActor
    func test_signUpWithPassword_withEmailVerificationLastStep_succeeds() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
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

        guard let codeRequiredState = try await startSignUpAndExpectCodeRequired(
            application: sut,
            username: username,
            password: password
        ) else {
            return
        }

        guard let code = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signInAfterSignUpRequiredExp = expectation(description: "sign in after sign up required")
        let delegate = SignUpV2DelegateSpy(expectation: signInAfterSignUpRequiredExp)
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
            username: username
        )
    }

    // Use case 1.1.2. Sign up - with Email & Password, Resend email OOB
    @MainActor
    func test_signUpWithEmailPassword_resendEmail_success() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
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

        let parameters = signUpParameters(username: username)

        let delegate = try await startSignUpAndSubmitPassword(application: sut, parameters: parameters, password: password)

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

    // Hero Scenario 1.1.3. Sign up - with Email verification as LAST step & Custom Attributes (Email & Password)
    @MainActor
    func test_signUpWithPassword_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .passwordAndAttributes,
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

        let parameters = signUpParameters(
            username: username,
            attributes: AttributesStub.allAttributes
        )

        let delegate = try await startSignUpAndSubmitPassword(application: sut, parameters: parameters, password: password)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return
        }
        checkCodeRequired(delegate)

        guard let code = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
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
            username: username
        )
    }

    // Hero Scenario 1.1.4. Sign up - with Email verification as FIRST step (Email & Password)
    @MainActor
    func test_signUpWithPassword_withEmailVerificationAsFirstStepAndThenSetPassword_succeeds() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
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

        guard let codeRequiredState = try await startSignUpAndExpectCodeRequired(
            application: sut,
            username: username
        ) else {
            return
        }

        guard let code = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let passwordRequiredExp = expectation(description: "password required after email verification")
        let delegate = SignUpV2DelegateSpy(expectation: passwordRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [passwordRequiredExp])

        guard delegate.onPasswordRequiredCalled,
              let passwordRequiredState = delegate.passwordRequiredState
        else {
            XCTFail("onPasswordRequired not called after email verification")
            return
        }
        XCTAssertEqual(delegate.scenario, .signUp)
        XCTAssertFalse(delegate.onSignInAfterSignUpRequiredCalled)

        let signInAfterSignUpRequiredExp = expectation(description: "sign in after sign up required")
        delegate.reset(expectation: signInAfterSignUpRequiredExp)
        passwordRequiredState.submitPassword(password, delegate: delegate)

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
            username: username
        )
    }

    // Use case 1.1.5. Sign up - with Email & Password, Verify email address using email OTP, resend OTP and then set password
    @MainActor
    func test_signUpWithEmailOTP_andSetPasswordAfterOTP_success() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
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
        let parameters = signUpParameters(username: username)

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

        guard let initialCode = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("Initial OTP code could not be retrieved")
            return
        }

        let resendCodeRequiredExp = expectation(description: "code resend required")
        delegate.reset(expectation: resendCodeRequiredExp)

        markEmailCheckpoint()
        codeRequiredState.resendCode(delegate: delegate)

        await fulfillment(of: [resendCodeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let resentCodeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("Resend code method should have been called")
            return
        }

        guard let newCode = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("Resent OTP code could not be retrieved")
            return
        }

        XCTAssertNotEqual(initialCode, newCode, "Resent code should be different from the initial code")

        let passwordRequiredExp = expectation(description: "password required after email verification")
        delegate.reset(expectation: passwordRequiredExp)
        resentCodeRequiredState.submitCode(newCode, delegate: delegate)

        await fulfillment(of: [passwordRequiredExp])
        try await submitCollectedPassword(password, delegate: delegate)

        XCTAssertTrue(delegate.onSignInAfterSignUpRequiredCalled, "Sign-up should complete successfully")
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertNotNil(delegate.signInAfterSignUpState)
    }

    // Hero Scenario 1.1.6. Sign up - with Email verification as FIRST step & Custom Attribute (Email & Password)
    @MainActor
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .passwordAndAttributes,
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
        let parameters = signUpParameters(username: username)

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

        guard let code = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let passwordRequiredExp = expectation(description: "password required after email verification")
        delegate.reset(expectation: passwordRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [passwordRequiredExp])
        try await submitCollectedPassword(password, delegate: delegate)

        guard delegate.onAttributesRequiredCalled,
              let attributesRequiredState = delegate.attributesRequiredState
        else {
            XCTFail("onAttributesRequired not called")
            return
        }

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
            username: username
        )
    }

    // Sign up - with Email verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Password)
    @MainActor
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        throw XCTSkip("Skipping test as currently v2 api only allows sending all attributes in one request.")
        
        guard let sut = initialisePublicClientApplication(
            clientIdType: .passwordAndAttributes,
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
        let parameters = signUpParameters(username: username)

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

        guard let code = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let passwordRequiredExp = expectation(description: "password required after email verification")
        delegate.reset(expectation: passwordRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [passwordRequiredExp])
        try await submitCollectedPassword(password, delegate: delegate)

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
            username: username
        )
    }

    // Sign up – without automatic sign in (Email & Password)
    @MainActor
    func test_signUpWithPasswordWithoutAutomaticSignIn() async throws {
        throw XCTSkip("Skipping test as currently prod API doesn't have send username on start")
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
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
        let parameters = signUpParameters(username: username)

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

        guard let code = await retrieveCodeFor(email: username, password: password) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let passwordRequiredExp = expectation(description: "password required after email verification")
        delegate.reset(expectation: passwordRequiredExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [passwordRequiredExp])
        try await submitCollectedPassword(password, delegate: delegate)

        XCTAssertTrue(delegate.onSignInAfterSignUpRequiredCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertNotNil(delegate.signInAfterSignUpState)
        XCTAssertFalse(delegate.onFlowCompletedCalled)
    }

    // Use case 1.1.10. Sign up - with Email & Password, User already exists with given email as email-pw account
    @MainActor
    func test_signUpWithEmailPassword_andAgainSameEmail_requiresExistingPassword() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ), let username = retrieveUsernameForSignInUsernameAndPassword() else {
            XCTFail("Missing information")
            return
        }

        let existingPasswordExp = expectation(description: "existing account password required")
        let delegate = SignUpV2DelegateSpy(expectation: existingPasswordExp)
        let parameters = signUpParameters(username: username)

        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [existingPasswordExp])

        XCTAssertNotNil(delegate.existingAccountPasswordRequiredState)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertFalse(delegate.onPasswordRequiredCalled)
        XCTAssertFalse(delegate.onFlowCompletedCalled)
        XCTAssertFalse(delegate.onFlowErrorCalled)
    }

    // Use case 1.1.11. Sign up - with Email & Password, User already exists with given email as social account
    @MainActor
    func test_signUpWithEmailPassword_socialAccount_fails() async throws {
        throw XCTSkip("Skipping test as it requires a Social account, not present in MSIDLAB")
    }

    // Use case 1.1.12. Sign up - with Email & Password, Developer makes a request with invalid format email address
    @MainActor
    func test_signUpWithEmailPassword_invalidEmail_fails() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let signUpFailureExp = expectation(description: "sign-up with invalid format email fails")
        let delegate = SignUpV2DelegateSpy(expectation: signUpFailureExp)
        let parameters = signUpParameters(username: "invalid")

        sut.signUpV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [signUpFailureExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
//        XCTAssertEqual(delegate.error?.isInvalidUsername, true) // TODO: we get general error right now ADO: https://identitydivision.visualstudio.com/Engineering/_workitems/edit/3776293
        XCTAssertEqual(delegate.error?.isGeneralError, true)
    }

    // Use case 1.1.13. Sign up - with Email & Password, Developer makes a request
    // with password that does not match password complexity requirements set on portal
    @MainActor
    func test_signUpWithEmailPassword_invalidPassword_fails() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let parameters = signUpParameters(username: generateSignUpRandomEmail())

        let delegate = try await startSignUpAndSubmitPassword(application: sut, parameters: parameters, password: "invalid")

        XCTAssertTrue(delegate.onFlowErrorCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
//        XCTAssertEqual(delegate.error?.isInvalidPassword, true) // TODO: we get general error right now ADO: https://identitydivision.visualstudio.com/Engineering/_workitems/edit/3776293
        XCTAssertEqual(delegate.error?.isGeneralError, true)
    }

    private func signUpParameters(
        username: String,
        attributes: [String: Any]? = nil
    ) -> MSALNativeAuthSignUpParametersV2 {
        let parameters = MSALNativeAuthSignUpParametersV2(username: username)
        var signUpAttributes = attributes ?? [:]
        // TODO: Remove this temporary requirement after these tests migrate to the ciam6 tenant.
        signUpAttributes["displayName"] = "Native Auth E2E User"
        parameters.attributes = signUpAttributes
        parameters.correlationId = correlationId
        return parameters
    }

    @MainActor
    private func startSignUpAndSubmitPassword(
        application: MSALNativeAuthPublicClientApplication,
        parameters: MSALNativeAuthSignUpParametersV2,
        password: String
    ) async throws -> SignUpV2DelegateSpy {
        let passwordRequiredExp = expectation(description: "password required before email verification")
        let delegate = SignUpV2DelegateSpy(expectation: passwordRequiredExp)
        application.signUpV2(parameters: parameters, delegate: delegate)
        await fulfillment(of: [passwordRequiredExp])

        try await submitCollectedPassword(password, delegate: delegate)
        return delegate
    }

    @MainActor
    private func submitCollectedPassword(_ password: String, delegate: SignUpV2DelegateSpy) async throws {
        XCTAssertTrue(delegate.onPasswordRequiredCalled)
        XCTAssertEqual(delegate.scenario, .signUp)
        let state = try XCTUnwrap(delegate.passwordRequiredState, "onPasswordRequired not called")
        let nextStepExp = expectation(description: "step after password submission")
        delegate.reset(expectation: nextStepExp)
        markEmailCheckpoint()
        state.submitPassword(password, delegate: delegate)
        await fulfillment(of: [nextStepExp])
        try skipIfEmailOTPThrottled(delegate.error)
    }

    @MainActor
    private func startSignUpAndExpectCodeRequired(
        application: MSALNativeAuthPublicClientApplication,
        username: String,
        password: String? = nil
    ) async throws -> MSALNativeAuthCodeRequiredState? {
        let delegate: SignUpV2DelegateSpy
        let parameters = signUpParameters(username: username)

        if let password {
            delegate = try await startSignUpAndSubmitPassword(
                application: application, parameters: parameters, password: password
            )
        } else {
            let codeRequiredExp = expectation(description: "code required")
            delegate = SignUpV2DelegateSpy(expectation: codeRequiredExp)
            markEmailCheckpoint()
            application.signUpV2(parameters: parameters, delegate: delegate)
            await fulfillment(of: [codeRequiredExp])
            try skipIfEmailOTPThrottled(delegate.error)
        }

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("OTP not sent")
            return nil
        }
        checkCodeRequired(delegate)
        return codeRequiredState
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

        state.signIn(delegate: delegate)

        await fulfillment(of: [flowCompletedExp])

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        let scenario = delegate.scenario
        XCTAssertEqual(scenario, .signUp)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertNotNil(delegate.result?.account.accountClaims)
        XCTAssertEqual(delegate.result?.account.username?.lowercased(), username.lowercased())
    }
}
