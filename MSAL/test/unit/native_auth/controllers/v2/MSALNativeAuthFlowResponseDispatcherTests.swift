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
@testable import MSAL
@_implementationOnly import MSAL_Private

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthFlowResponseDispatcherTests: XCTestCase {

    private let sut = MSALNativeAuthFlowResponseDispatcher()

    // MARK: - completed

    func test_dispatch_completed_callsOnFlowCompletedAndTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .completed(MSALNativeAuthUserAccountResultStub.result),
            correlationId: UUID(),
            scenario: .signIn,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.completedScenario, .signIn)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - error

    func test_dispatch_error_callsOnFlowErrorAndDoesNotFireTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let error = MSALNativeAuthFlowError(type: .invalidCode)
        let response = MSALNativeAuthFlowControllerResponse(
            .error(error: error),
            correlationId: UUID(),
            scenario: .passwordReset,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.error === error)
        XCTAssertEqual(delegate.errorScenario, .passwordReset)
        XCTAssertFalse(telemetryFired)
    }

    // MARK: - browserRequired

    func test_dispatch_browserRequired_callsOnFlowErrorWithBrowserRequiredAndTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .browserRequired,
            correlationId: UUID(),
            scenario: .signUp,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, .signUp)
        XCTAssertTrue(delegate.error?.isBrowserRequired ?? false)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - actionRequired: delegate conforms

    func test_dispatch_registrationRequired_deliversTypedCallbackOnMainThread() async {
        let delegate = StrongAuthDelegateSpy()
        let state = MSALNativeAuthStrongAuthRegistrationRequiredState(
            internalState: makeInternalState(), offeredMethods: []
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state), correlationId: UUID(),
            telemetryUpdate: { telemetryResult = $0 }
        )
        await sut.dispatch(response, delegate: delegate)
        XCTAssertTrue(delegate.registrationState === state)
        XCTAssertEqual(delegate.strongAuthScenario, .signIn)
        XCTAssertTrue(delegate.calledOnMainThread)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_activationRequired_deliversTypedCallbackOnMainThread() async {
        let delegate = StrongAuthDelegateSpy()
        let state = MSALNativeAuthStrongAuthVerificationRequiredState(
            internalState: makeInternalState(),
            sentTo: "+1******0100",
            channel: MSALNativeAuthChannelType(value: "sms"),
            codeLength: 6
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state), correlationId: UUID(),
            telemetryUpdate: { telemetryResult = $0 }
        )
        await sut.dispatch(response, delegate: delegate)
        XCTAssertTrue(delegate.activationState === state)
        XCTAssertEqual(delegate.strongAuthScenario, .signIn)
        XCTAssertTrue(delegate.calledOnMainThread)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_registrationRequired_missingDelegate_reportsNotImplemented() async {
        await assertNotImplemented(
            for: MSALNativeAuthStrongAuthRegistrationRequiredState(internalState: makeInternalState(), offeredMethods: []),
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthStrongAuthRegistrationRequiredDelegate"
        )
    }

    func test_dispatch_activationRequired_missingDelegate_reportsNotImplemented() async {
        await assertNotImplemented(
            for: MSALNativeAuthStrongAuthVerificationRequiredState(
                internalState: makeInternalState(),
                sentTo: "+1******0100",
                channel: MSALNativeAuthChannelType(value: "sms"),
                codeLength: 6
            ),
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthStrongAuthVerificationRequiredDelegate"
        )
    }

    func test_dispatch_actionRequired_conformingDelegate_callsTypedCallbackAndTelemetry() async {
        let delegate = CodeRequiredDelegateSpy()
        let internalState = makeInternalState(scenario: .signUp)
        let state = MSALNativeAuthCodeRequiredState(
            internalState: internalState,
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.codeRequiredState === state)
        // The scenario is taken from the state's continuation, not from response.scenario.
        XCTAssertEqual(delegate.codeRequiredScenario, .signUp)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_authMethodSelectionRequired_conformingDelegate_callsTypedCallbackAndTelemetry() async {
        let delegate = AuthMethodSelectionRequiredDelegateSpy()
        let internalState = makeInternalState(scenario: .passwordReset)
        let state = MSALNativeAuthAuthMethodSelectionRequiredState(
            internalState: internalState,
            authMethods: [
                MSALAuthMethod(
                    id: "sms-id",
                    challengeType: "sms",
                    channelTargetType: MSALNativeAuthChannelType(value: "sms"),
                    loginHint: "+1********00"
                )
            ]
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.authMethodSelectionRequiredState === state)
        XCTAssertEqual(delegate.authMethodSelectionRequiredScenario, .passwordReset)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_signInAfterResetPassword_callsTypedCallbackAndTelemetry() async {
        let delegate = V2SignInAfterResetPasswordDelegateSpy()
        let internalState = makeInternalState(scenario: .passwordReset)
        let state = MSALNativeAuthSignInAfterResetPasswordState(internalState: internalState)
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.signInAfterResetPasswordState === state)
        XCTAssertEqual(delegate.signInAfterResetPasswordScenario, .passwordReset)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - actionRequired: delegate does not conform (notImplemented surfaces the delegate name)

    func test_dispatch_mfaVerification_preservesSupportedFlowScenarios() async {
        for scenario: MSALNativeAuthFlowScenario in [.signIn, .passwordReset] {
            let delegate = MFAVerificationDelegateSpy()
            let state = MSALNativeAuthMFAVerificationRequiredState(
                internalState: makeInternalState(scenario: scenario),
                sentTo: "",
                channel: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
            let response = MSALNativeAuthFlowControllerResponse(.actionRequired(state: state), correlationId: UUID())
            await sut.dispatch(response, delegate: delegate)
            XCTAssertTrue(delegate.verificationState === state)
            XCTAssertEqual(delegate.verificationScenario, scenario)
            XCTAssertNil(delegate.error)
        }
    }

    func test_authMethodSelection_callsPrimaryControllerDirectly() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: .signIn, controller: controller)
        let method = MSALAuthMethod(
            id: "email-id", challengeType: "email", channelTargetType: MSALNativeAuthChannelType(value: "email"), loginHint: nil
        )
        let expected = MSALNativeAuthFlowError(type: .generalError)
        controller.selectAuthMethodResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: expected), correlationId: UUID(), scenario: .signIn
        )
        let state = MSALNativeAuthAuthMethodSelectionRequiredState(internalState: internalState, authMethods: [method])
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "Selection callback")
        delegate.errorCallback = { callback.fulfill() }

        state.selectAuthMethod(method, delegate: delegate)
        await fulfillment(of: [callback], timeout: 1)

        XCTAssertTrue(controller.selectedAuthMethod === method)
        XCTAssertTrue(controller.selectedAuthMethodState === internalState)
        XCTAssertNil(controller.selectedMFAAuthMethod)
        XCTAssertNil(controller.enrolledAuthMethod)
        XCTAssertTrue(delegate.error === expected)
    }

    func test_mfaMethodSelection_existingCallbackPreservesMFAControllerPath() async throws {
        for scenario: MSALNativeAuthFlowScenario in [.signIn, .passwordReset] {
            let controller = MSALNativeAuthFlowControllerMock()
            let internalState = makeInternalState(scenario: scenario, controller: controller)
            let method = MSALAuthMethod(
                id: "email-id", challengeType: "email", channelTargetType: MSALNativeAuthChannelType(value: "email"), loginHint: nil
            )
            let expected = MSALNativeAuthFlowError(type: .generalError)
            controller.selectMFAAuthMethodResponse = MSALNativeAuthFlowControllerResponse(
                .error(error: expected), correlationId: UUID(), scenario: scenario
            )
            let state = MSALNativeAuthMFAMethodSelectionRequiredState(internalState: internalState, authMethods: [method])
            let delegate = AuthMethodSelectionRequiredDelegateSpy()
            var telemetryResult: Result<Void, MSALNativeAuthError>?
            let response = MSALNativeAuthFlowControllerResponse(
                .actionRequired(state: state), correlationId: UUID(),
                telemetryUpdate: { telemetryResult = $0 }
            )

            await sut.dispatch(response, delegate: delegate)

            let deliveredState = try XCTUnwrap(delegate.authMethodSelectionRequiredState)
            XCTAssertTrue(deliveredState === state)
            XCTAssertEqual(delegate.authMethodSelectionRequiredScenario, scenario)
            XCTAssertTrue(delegate.calledOnMainThread)
            XCTAssertNil(delegate.error)
            assertTelemetrySuccess(telemetryResult)
            let callback = expectation(description: "MFA selection callback")
            delegate.errorCallback = { callback.fulfill() }

            deliveredState.selectAuthMethod(method, delegate: delegate)
            await fulfillment(of: [callback], timeout: 1)

            XCTAssertTrue(controller.selectedMFAAuthMethod === method)
            XCTAssertTrue(controller.selectedMFAAuthMethodState === internalState)
            XCTAssertNil(controller.selectedAuthMethod)
            XCTAssertNil(controller.enrolledAuthMethod)
            XCTAssertTrue(delegate.error === expected)
            XCTAssertEqual(delegate.errorScenario, scenario)
        }
    }

    func test_strongAuthRegistration_forwardsOfferedMethodsToEnrollment() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: .signUp, controller: controller)
        let offered = MSALNativeAuthV2EnrollmentMethod(
            id: "email-id", enrollHref: "https://contoso.com/email", channelType: .email
        )
        let state = MSALNativeAuthStrongAuthRegistrationRequiredState(internalState: internalState, offeredMethods: [offered])
        let selected = MSALAuthMethod(
            id: offered.id, challengeType: "sms", channelTargetType: MSALNativeAuthChannelType(value: "sms"), loginHint: nil
        )
        let expected = MSALNativeAuthFlowError(type: .invalidInput)
        controller.enrollAuthMethodResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: expected), correlationId: UUID(), scenario: .signUp
        )
        XCTAssertEqual(state.authMethods.first?.channelTargetType.value, "email")

        for contact: String? in ["test@example.com", nil] {
            let delegate = BaseDelegateSpy()
            let callback = expectation(description: "Enrollment callback")
            delegate.errorCallback = { callback.fulfill() }
            if let contact {
                state.selectAuthMethod(selected, verificationContact: contact, delegate: delegate)
            } else {
                state.selectAuthMethod(selected, delegate: delegate)
            }
            await fulfillment(of: [callback], timeout: 1)

            XCTAssertTrue(controller.enrolledAuthMethod === selected)
            XCTAssertEqual(controller.offeredEnrollmentMethods?.map(\.id), [offered.id])
            XCTAssertEqual(controller.offeredEnrollmentMethods?.first?.channelType, .email)
            XCTAssertEqual(controller.offeredEnrollmentMethods?.first?.enrollHref, offered.enrollHref)
            XCTAssertEqual(controller.selectedVerificationContact, contact)
            XCTAssertTrue(controller.selectedAuthMethodState === internalState)
            XCTAssertNil(controller.selectedAuthMethod)
            XCTAssertTrue(delegate.error === expected)
            XCTAssertEqual(delegate.errorScenario, .signUp)
        }
    }

    func test_mfaVerification_submitCallsMFAControllerDirectly() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: .passwordReset, controller: controller)
        let expected = MSALNativeAuthFlowError(type: .invalidCode)
        controller.submitMFAChallengeResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: expected), correlationId: UUID(), scenario: .passwordReset
        )
        let state = MSALNativeAuthMFAVerificationRequiredState(
            internalState: internalState, sentTo: "", channel: MSALNativeAuthChannelType(value: "email"), codeLength: 8
        )
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "MFA submission callback")
        delegate.errorCallback = { callback.fulfill() }

        state.submitChallenge("12345678", delegate: delegate)
        await fulfillment(of: [callback], timeout: 1)

        XCTAssertEqual(controller.submittedMFAChallenge, "12345678")
        XCTAssertTrue(controller.submittedMFAChallengeState === internalState)
        XCTAssertNil(controller.submittedStrongAuthChallenge)
        XCTAssertTrue(delegate.error === expected)
        XCTAssertEqual(delegate.errorScenario, .passwordReset)
    }

    func test_strongAuthVerification_submitCallsStrongAuthControllerDirectly() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: .signUp, controller: controller)
        let expected = MSALNativeAuthFlowError(type: .invalidCode)
        controller.submitStrongAuthChallengeResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: expected), correlationId: UUID(), scenario: .signUp
        )
        let state = MSALNativeAuthStrongAuthVerificationRequiredState(
            internalState: internalState, sentTo: "", channel: MSALNativeAuthChannelType(value: "sms"), codeLength: 6
        )
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "JIT submission callback")
        delegate.errorCallback = { callback.fulfill() }

        state.submitChallenge("123456", delegate: delegate)
        await fulfillment(of: [callback], timeout: 1)

        XCTAssertEqual(controller.submittedStrongAuthChallenge, "123456")
        XCTAssertTrue(controller.submittedStrongAuthChallengeState === internalState)
        XCTAssertNil(controller.submittedMFAChallenge)
        XCTAssertTrue(delegate.error === expected)
        XCTAssertEqual(delegate.errorScenario, .signUp)
    }

    func test_mfaVerification_resendUsesMFAControllerPath() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: .passwordReset, controller: controller)
        let expected = MSALNativeAuthFlowError(type: .invalidCode)
        controller.resendMFAChallengeResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: expected), correlationId: UUID(), scenario: .passwordReset
        )
        let state = MSALNativeAuthMFAVerificationRequiredState(
            internalState: internalState, sentTo: "", channel: MSALNativeAuthChannelType(value: "email"), codeLength: 8
        )
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "MFA resend callback")
        delegate.errorCallback = { callback.fulfill() }

        state.resendChallenge(delegate: delegate)
        await fulfillment(of: [callback], timeout: 1)

        XCTAssertTrue(controller.resendMFAChallengeCalled)
        XCTAssertFalse(controller.resendStrongAuthChallengeCalled)
        XCTAssertEqual(controller.resendMFAChallengeChannel?.value, state.channel.value)
        XCTAssertTrue(controller.resendMFAChallengeState === internalState)
        XCTAssertTrue(delegate.error === expected)
        XCTAssertEqual(delegate.errorScenario, .passwordReset)
    }

    func test_strongAuthVerification_resendUsesStrongAuthControllerPath() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: .signUp, controller: controller)
        let expected = MSALNativeAuthFlowError(type: .generalError)
        controller.resendStrongAuthChallengeResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: expected), correlationId: UUID(), scenario: .signUp
        )
        let state = MSALNativeAuthStrongAuthVerificationRequiredState(
            internalState: internalState, sentTo: "", channel: MSALNativeAuthChannelType(value: "sms"), codeLength: 6
        )
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "JIT resend callback")
        delegate.errorCallback = { callback.fulfill() }

        state.resendChallenge(delegate: delegate)
        await fulfillment(of: [callback], timeout: 1)

        XCTAssertTrue(controller.resendStrongAuthChallengeCalled)
        XCTAssertFalse(controller.resendMFAChallengeCalled)
        XCTAssertEqual(controller.resendStrongAuthChallengeChannel?.value, state.channel.value)
        XCTAssertTrue(controller.resendStrongAuthChallengeState === internalState)
        XCTAssertTrue(delegate.error === expected)
        XCTAssertEqual(delegate.errorScenario, .signUp)
    }

    func test_dispatch_codeRequired_nonConformingDelegate_callsNotImplementedWithDelegateNameAndSkipsTelemetry() async {
        let state = MSALNativeAuthCodeRequiredState(
            internalState: makeInternalState(scenario: .signIn),
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthCodeRequiredDelegate"
        )
    }

    func test_dispatch_passwordRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthPasswordRequiredState(internalState: makeInternalState(scenario: .signIn))
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthPasswordRequiredDelegate"
        )
    }

    func test_dispatch_mfaRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthMFAMethodSelectionRequiredState(
            internalState: makeInternalState(scenario: .signIn), authMethods: []
        )
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthAuthMethodSelectionRequiredDelegate"
        )
    }

    func test_dispatch_mfaVerificationRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthMFAVerificationRequiredState(
            internalState: makeInternalState(scenario: .signIn),
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthMFAVerificationRequiredDelegate"
        )
    }

    func test_dispatch_authMethodSelectionRequired_nonConformingDelegate_callsNotImplementedWithScenarioAndCorrelation() async {
        let correlationId = UUID()
        let state = MSALNativeAuthAuthMethodSelectionRequiredState(
            internalState: makeInternalState(scenario: .signIn),
            authMethods: []
        )
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: correlationId,
            scenario: .unknown,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, .signIn)
        XCTAssertTrue(delegate.error?.isNotImplemented ?? false)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "MSALNativeAuthAuthMethodSelectionRequiredDelegate")
        )
        XCTAssertFalse(telemetryFired)
    }

    func test_dispatch_newPasswordRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthNewPasswordRequiredState(internalState: makeInternalState(scenario: .passwordReset))
        await assertNotImplemented(
            for: state,
            expectedScenario: .passwordReset,
            expectedDelegateName: "MSALNativeAuthNewPasswordRequiredDelegate"
        )
    }

    func test_dispatch_signInAfterResetPassword_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthSignInAfterResetPasswordState(internalState: makeInternalState(scenario: .passwordReset))
        await assertNotImplemented(
            for: state,
            expectedScenario: .passwordReset,
            expectedDelegateName: "MSALNativeAuthSignInAfterResetPasswordRequiredDelegate"
        )
    }

    // MARK: - Helpers

    private func makeInternalState(
        scenario: MSALNativeAuthFlowScenario = .signIn,
        controller: MSALNativeAuthFlowControlling = MSALNativeAuthFlowControllerMock()
    ) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: scenario,
            correlationId: UUID(),
            continuationToken: "ct",
            links: [:]
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: controller)
    }

    private func assertNotImplemented(
        for state: MSALNativeAuthState,
        expectedScenario: MSALNativeAuthFlowScenario,
        expectedDelegateName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, expectedScenario, file: file, line: line)
        XCTAssertTrue(delegate.error?.isNotImplemented ?? false, file: file, line: line)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, expectedDelegateName),
            file: file,
            line: line
        )
        XCTAssertFalse(telemetryFired, file: file, line: line)
    }

    private func assertTelemetrySuccess(
        _ result: Result<Void, MSALNativeAuthError>?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success = result else {
            return XCTFail("Expected telemetry success", file: file, line: line)
        }
    }
}

// MARK: - Delegate spies

private class BaseDelegateSpy: NSObject, MSALNativeAuthFlowDelegate {

    var completedScenario: MSALNativeAuthFlowScenario?
    var error: MSALNativeAuthFlowError?
    var errorScenario: MSALNativeAuthFlowScenario?
    var errorCallback: (() -> Void)?

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        completedScenario = scenario
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        self.error = error
        errorScenario = scenario
        errorCallback?()
    }
}

private final class MFAVerificationDelegateSpy: BaseDelegateSpy, MSALNativeAuthMFAVerificationRequiredDelegate {
    var verificationState: MSALNativeAuthMFAVerificationRequiredState?
    var verificationScenario: MSALNativeAuthFlowScenario?

    func onMFAVerificationRequired(state: MSALNativeAuthMFAVerificationRequiredState, scenario: MSALNativeAuthFlowScenario) {
        verificationState = state
        verificationScenario = scenario
    }
}

private final class StrongAuthDelegateSpy: BaseDelegateSpy,
    MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
    MSALNativeAuthStrongAuthVerificationRequiredDelegate {

    var registrationState: MSALNativeAuthStrongAuthRegistrationRequiredState?
    var activationState: MSALNativeAuthStrongAuthVerificationRequiredState?
    var strongAuthScenario: MSALNativeAuthFlowScenario?
    var calledOnMainThread = false

    func onStrongAuthRegistrationRequired(
        state: MSALNativeAuthStrongAuthRegistrationRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        registrationState = state
        strongAuthScenario = scenario
        calledOnMainThread = Thread.isMainThread
    }

    func onStrongAuthVerificationRequired(
        state: MSALNativeAuthStrongAuthVerificationRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        activationState = state
        strongAuthScenario = scenario
        calledOnMainThread = Thread.isMainThread
    }
}

private final class CodeRequiredDelegateSpy: BaseDelegateSpy, MSALNativeAuthCodeRequiredDelegate {

    var codeRequiredState: MSALNativeAuthCodeRequiredState?
    var codeRequiredScenario: MSALNativeAuthFlowScenario?

    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        codeRequiredState = state
        codeRequiredScenario = scenario
    }
}

private final class AuthMethodSelectionRequiredDelegateSpy: BaseDelegateSpy, MSALNativeAuthAuthMethodSelectionRequiredDelegate {

    var authMethodSelectionRequiredState: MSALNativeAuthAuthMethodSelectionRequiredState?
    var authMethodSelectionRequiredScenario: MSALNativeAuthFlowScenario?
    var calledOnMainThread = false

    func onAuthMethodSelectionRequired(
        state: MSALNativeAuthAuthMethodSelectionRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        authMethodSelectionRequiredState = state
        authMethodSelectionRequiredScenario = scenario
        calledOnMainThread = Thread.isMainThread
    }
}

private final class V2SignInAfterResetPasswordDelegateSpy: BaseDelegateSpy, MSALNativeAuthSignInAfterResetPasswordRequiredDelegate {

    var signInAfterResetPasswordState: MSALNativeAuthSignInAfterResetPasswordState?
    var signInAfterResetPasswordScenario: MSALNativeAuthFlowScenario?

    func onSignInAfterResetPasswordRequired(
        state: MSALNativeAuthSignInAfterResetPasswordState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        signInAfterResetPasswordState = state
        signInAfterResetPasswordScenario = scenario
    }
}
