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

final class MSALNativeAuthSignInUsernameV2EndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("SignIn V2 requires a test slice. Disable this test until api is in prod.")
    }

    // Hero Scenario 2.2.1. Sign in - Use email and OTP to get token and sign in
    @MainActor
    func test_signInAndSendingCorrectOTPResultsInSuccess() async throws {
        try await assertSignInWithEmailOTPSucceeds(authorityURLFormat: .tenantSubdomainTenantId)
    }

    // Hero Scenario 2.2.2. Sign in - User is not registered with given email
    @MainActor
    func test_signInWithUnknownUsernameResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let flowErrorExp = expectation(description: "sign in flow error")
        let delegate = SignInV2DelegateSpy(expectation: flowErrorExp)

        let parameters = MSALNativeAuthSignInParameters(username: UUID().uuidString + "@contoso.com")
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowErrorExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isUserNotFound, true)
    }

    // User Case 2.2.3 Sign In - User email is registered with password method, which is not supported by client (aka redirect flow)
    @MainActor
    func test_signInWithPasswordConfigInsufficientChallengeResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(
            clientIdType: .password,
            challengeTypes: .OOB,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ), let username = retrieveUsernameForSignInUsernameAndPassword()
        else {
            XCTFail("Missing information")
            return
        }

        let flowErrorExp = expectation(description: "sign in flow error")
        let delegate = SignInV2DelegateSpy(expectation: flowErrorExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowErrorExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isBrowserRequired, true)
    }

    // User Case 2.2.5 Sign In - Resend email OTP
    @MainActor
    func test_signInWithEmailOTP_resendEmail_success() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignInV2DelegateSpy(expectation: codeRequiredExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.correlationId = correlationId
        markEmailCheckpoint()
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("onCodeRequired not called")
            return
        }

        guard let code1 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let resendCodeRequiredExp = expectation(description: "code required again")
        delegate.reset(expectation: resendCodeRequiredExp)

        markEmailCheckpoint()
        codeRequiredState.resendCode(delegate: delegate)

        await fulfillment(of: [resendCodeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let resentCodeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("onCodeRequired should be called again after resend")
            return
        }

        guard let code2 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        XCTAssertNotEqual(code1, code2, "Resent code should be different from the original code")

        let flowCompletedExp = expectation(description: "sign in flow completed")
        delegate.reset(expectation: flowCompletedExp)
        resentCodeRequiredState.submitCode(code2, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])
        try skipIfEmailOTPThrottled(delegate.error)

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertEqual(delegate.result?.account.username, username)
    }

    // Hero Scenario 2.2.7. Sign in - Invalid OTP code
    @MainActor
    func test_signInAndSendingIncorrectOTPResultsInError() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: .tenantSubdomainTenantId
        ) else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignInV2DelegateSpy(expectation: codeRequiredExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.correlationId = correlationId
        markEmailCheckpoint()
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("onCodeRequired not called")
            return
        }

        let flowErrorExp = expectation(description: "sign in flow error")
        delegate.reset(expectation: flowErrorExp)
        codeRequiredState.submitCode("00000000", delegate: delegate)

        await fulfillment(of: [flowErrorExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isInvalidCode, true)
    }

    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantName>.onmicrosoft.com"
    @MainActor
    func test_signInCustomSubdomainLongInSuccess() async throws {
        try await assertSignInWithEmailOTPSucceeds(authorityURLFormat: .tenantSubdomainLongVersion)
    }

    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantId>"
    @MainActor
    func test_signInCustomSubdomainIdInSuccess() async throws {
        try await assertSignInWithEmailOTPSucceeds(authorityURLFormat: .tenantSubdomainTenantId)
    }

    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/"
    @MainActor
    func test_signInCustomSubdomainShortInSuccess() async throws {
        try await assertSignInWithEmailOTPSucceeds(authorityURLFormat: .tenantSubdomainShortVersion)
    }

    @MainActor
    private func assertSignInWithEmailOTPSucceeds(authorityURLFormat: AuthorityURLFormat) async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(
            clientIdType: .code,
            customAuthorityURLFormat: authorityURLFormat
        ) else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignInV2DelegateSpy(expectation: codeRequiredExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.correlationId = correlationId
        markEmailCheckpoint()
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("onCodeRequired not called")
            return
        }

        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertGreaterThan(delegate.codeLength, 0)

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let flowCompletedExp = expectation(description: "sign in flow completed")
        delegate.reset(expectation: flowCompletedExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])
        try skipIfEmailOTPThrottled(delegate.error)

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertEqual(delegate.result?.account.username, username)
    }
}
