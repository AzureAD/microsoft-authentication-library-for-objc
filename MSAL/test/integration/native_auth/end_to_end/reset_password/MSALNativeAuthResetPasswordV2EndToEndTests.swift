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

/// End-to-end tests for the V2 (server-driven) self-service-password-reset flow exposed through
/// `MSALNativeAuthPublicClientApplication.resetPasswordV2(parameters:delegate:)`.
///
/// Unlike the V1 suite — which uses a different delegate protocol per step — V2 drives the whole
/// flow through a single unified delegate. The SDK reports each server-requested step
/// (`onCodeRequired`, `onNewPasswordRequired`) and the two terminal callbacks
/// (`onFlowCompleted`, `onFlowError`), and the app continues by calling methods on the
/// `MSALNativeAuthState` it is handed.
final class MSALNativeAuthResetPasswordV2EndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    // Number of times a submitted OTP is retried when the server reports it as invalid (races with
    // email delivery / an older code being read before the fresh one arrives).
    private let codeRetryCount = 3

    // SSPR – happy path: start → code required → new password required → flow completed (tokens).
    func test_resetPasswordV2_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = ResetPasswordV2DelegateSpy(expectation: codeRequiredExp)

        markEmailCheckpoint()

        let parameters = MSALNativeAuthResetPasswordParametersV2(username: username)
        sut.resetPasswordV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])

        guard delegate.onCodeRequiredCalled, let codeRequiredState = delegate.codeRequiredState else {
            XCTFail("onCodeRequired not called")
            return
        }

        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)

        // Now submit the code...
        guard let newPasswordRequiredState = await retrieveAndSubmitCode(delegate: delegate,
                                                                         codeRequiredState: codeRequiredState,
                                                                         username: username,
                                                                         retries: codeRetryCount)
        else {
            return
        }

        // Now submit the new password...
        let flowCompletedExp = expectation(description: "reset password flow completed")
        delegate.reset(expectation: flowCompletedExp)

        let uniquePassword = generateRandomPassword()
        newPasswordRequiredState.submitNewPassword(uniquePassword, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])
        XCTAssertTrue(delegate.onFlowCompletedCalled)
        XCTAssertEqual(delegate.scenario, .passwordReset)
        XCTAssertNotNil(delegate.result)
    }

    // SSPR – the new password being set doesn't meet the complexity requirements set on the portal.
    func test_resetPasswordV2_passwordComplexity_error() async throws {
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = ResetPasswordV2DelegateSpy(expectation: codeRequiredExp)

        markEmailCheckpoint()

        let parameters = MSALNativeAuthResetPasswordParametersV2(username: username)
        sut.resetPasswordV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])

        guard delegate.onCodeRequiredCalled, let codeRequiredState = delegate.codeRequiredState else {
            XCTFail("onCodeRequired not called")
            return
        }

        // Now submit the code...
        guard let newPasswordRequiredState = await retrieveAndSubmitCode(delegate: delegate,
                                                                         codeRequiredState: codeRequiredState,
                                                                         username: username,
                                                                         retries: codeRetryCount)
        else {
            return
        }

        // Now submit an invalid password...
        let flowErrorExp = expectation(description: "reset password flow error")
        delegate.reset(expectation: flowErrorExp)

        newPasswordRequiredState.submitNewPassword("INVALID_PASSWORD", delegate: delegate)

        await fulfillment(of: [flowErrorExp])
        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.error?.isInvalidPassword, true)
    }

    // SSPR – resend email OTP.
    func test_resetPasswordV2_resendCode_succeeds() async throws {
        throw XCTSkip("Skipped: resending the OTP repeatedly hits Entra throttling (AADSTS701014: \"Cannot generate more one time passcodes\"), which makes this test fail intermittently.")

        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = ResetPasswordV2DelegateSpy(expectation: codeRequiredExp)

        markEmailCheckpoint()

        let parameters = MSALNativeAuthResetPasswordParametersV2(username: username)
        sut.resetPasswordV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])

        guard delegate.onCodeRequiredCalled, let codeRequiredState = delegate.codeRequiredState else {
            XCTFail("onCodeRequired not called")
            return
        }

        // Now get code1...
        guard let code1 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        // Resend code
        let resendCodeRequiredExp = expectation(description: "code required again")
        delegate.reset(expectation: resendCodeRequiredExp)

        markEmailCheckpoint()
        codeRequiredState.resendCode(delegate: delegate)

        await fulfillment(of: [resendCodeRequiredExp])
        XCTAssertTrue(delegate.onCodeRequiredCalled, "onCodeRequired should be called again after resend")

        // Now get code2...
        guard let code2 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        XCTAssertNotEqual(code1, code2, "Resent code should be different from the original code")
    }

    // SSPR – email is not found in records.
    func test_resetPasswordV2_emailNotFound_error() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }

        let flowErrorExp = expectation(description: "reset password user not found")
        let delegate = ResetPasswordV2DelegateSpy(expectation: flowErrorExp)

        let unknownUsername = UUID().uuidString + "@contoso.com"

        let parameters = MSALNativeAuthResetPasswordParametersV2(username: unknownUsername)
        sut.resetPasswordV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowErrorExp])
        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.error?.isUserNotFound, true)
    }

    // Tries to fetch a code from the email provider (mail.tm) and submit it, retrying on an invalid
    // code, and returns the resulting new-password-required state.
    private func retrieveAndSubmitCode(delegate: ResetPasswordV2DelegateSpy,
                                       codeRequiredState: MSALNativeAuthCodeRequiredState,
                                       username: String,
                                       retries: Int) async -> MSALNativeAuthNewPasswordRequiredState? {
        let newPasswordRequiredExp = expectation(description: "new password required")
        delegate.reset(expectation: newPasswordRequiredExp)

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code not retrieved from email")
            return nil
        }

        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [newPasswordRequiredExp])

        if delegate.onFlowErrorCalled, delegate.error?.isInvalidCode == true, retries > 0 {
            return await retrieveAndSubmitCode(delegate: delegate,
                                               codeRequiredState: codeRequiredState,
                                               username: username,
                                               retries: retries - 1)
        }

        guard delegate.onNewPasswordRequiredCalled, let newPasswordRequiredState = delegate.newPasswordRequiredState else {
            XCTFail("onNewPasswordRequired not called")
            return nil
        }

        return newPasswordRequiredState
    }
}

/// Unified spy delegate for the V2 reset-password flow. A single instance receives every callback
/// across the flow; `reset(expectation:)` swaps in a fresh expectation and clears the per-step flags
/// before each continuation call.
class ResetPasswordV2DelegateSpy: NSObject, MSALNativeAuthCodeRequiredDelegate, MSALNativeAuthNewPasswordRequiredDelegate {
    private var expectation: XCTestExpectation

    private(set) var onCodeRequiredCalled = false
    private(set) var onNewPasswordRequiredCalled = false
    private(set) var onFlowCompletedCalled = false
    private(set) var onFlowErrorCalled = false

    private(set) var codeRequiredState: MSALNativeAuthCodeRequiredState?
    private(set) var newPasswordRequiredState: MSALNativeAuthNewPasswordRequiredState?
    private(set) var result: MSALNativeAuthUserAccountResult?
    private(set) var error: MSALNativeAuthFlowError?
    private(set) var scenario: MSALNativeAuthFlowScenario?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func reset(expectation: XCTestExpectation) {
        self.expectation = expectation
        onCodeRequiredCalled = false
        onNewPasswordRequiredCalled = false
        onFlowCompletedCalled = false
        onFlowErrorCalled = false
        error = nil
    }

    @MainActor
    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        onCodeRequiredCalled = true
        codeRequiredState = state
        sentTo = state.sentTo
        channelTargetType = state.channel
        codeLength = state.codeLength
        self.scenario = scenario

        expectation.fulfill()
    }

    @MainActor
    func onNewPasswordRequired(state: MSALNativeAuthNewPasswordRequiredState, scenario: MSALNativeAuthFlowScenario) {
        onNewPasswordRequiredCalled = true
        newPasswordRequiredState = state
        self.scenario = scenario

        expectation.fulfill()
    }

    @MainActor
    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        onFlowCompletedCalled = true
        self.result = result
        self.scenario = scenario

        expectation.fulfill()
    }

    @MainActor
    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        onFlowErrorCalled = true
        self.error = error
        self.scenario = scenario

        expectation.fulfill()
    }
}
