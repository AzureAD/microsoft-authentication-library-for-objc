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
        let state = MSALNativeAuthMFARequiredState(internalState: makeInternalState(scenario: .signIn), authMethods: [])
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthMFARequiredDelegate"
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
            internalState: makeInternalState(scenario: .passwordReset),
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

        XCTAssertEqual(delegate.errorScenario, .passwordReset)
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

    private func makeInternalState(scenario: MSALNativeAuthFlowScenario = .signIn) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: scenario,
            correlationId: UUID(),
            continuationToken: "ct",
            links: [:]
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: MSALNativeAuthFlowControllerMock())
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

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        completedScenario = scenario
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        self.error = error
        errorScenario = scenario
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

    func onAuthMethodSelectionRequired(
        state: MSALNativeAuthAuthMethodSelectionRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        authMethodSelectionRequiredState = state
        authMethodSelectionRequiredScenario = scenario
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
