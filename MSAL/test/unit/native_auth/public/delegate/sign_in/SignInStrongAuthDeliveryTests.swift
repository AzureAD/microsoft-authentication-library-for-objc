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

@MainActor
final class SignInStrongAuthDeliveryTests: XCTestCase {
    private typealias Telemetry = (Result<Void, MSALNativeAuthError>) -> Void
    private typealias Delivery = (MissingDelegate, @escaping Telemetry) async -> Void
    private let correlationId = UUID()

    func test_registrationRequired_deliversExactStateAndMethodsOnceAfterTelemetry() async {
        let state = RegisterStrongAuthState(
            controller: MSALNativeAuthJITControllerMock(), continuationToken: "registration-token", correlationId: correlationId
        )
        let methods = [MSALAuthMethod(id: "email", challengeType: "oob", channelTargetType: .init(value: "email"), loginHint: "t***")]

        for (_, delivery) in registrationDeliveries(state: state, methods: methods) {
            let delegate = SupportedDelegate()
            var events: [String] = []
            delegate.onRegistration = { receivedMethods, receivedState in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(receivedMethods.count, 1)
                XCTAssertTrue(receivedMethods.first === methods.first)
                XCTAssertTrue(receivedState === state)
                events.append("delegate")
            }
            await delivery(delegate) { result in
                guard case .success = result else { return XCTFail("Expected successful registration delivery") }
                events.append("telemetry")
            }
            XCTAssertEqual(events, ["telemetry", "delegate"])
            XCTAssertTrue(delegate.errors.isEmpty)
        }
    }

    func test_registrationRequired_missingOptionalMethodDeliversSameTypedErrorOnce() async throws {
        let state = RegisterStrongAuthState(
            controller: MSALNativeAuthJITControllerMock(), continuationToken: "registration-token", correlationId: correlationId
        )
        for (errorType, delivery) in registrationDeliveries(state: state, methods: []) {
            let delegate = MissingDelegate()
            var telemetryErrors: [MSALNativeAuthError] = []
            await delivery(delegate) { result in
                guard case .failure(let error) = result else { return XCTFail("Expected missing-delegate error") }
                telemetryErrors.append(error)
            }
            try assertMissingMethod(
                delegate: delegate, telemetryErrors: telemetryErrors,
                errorType: errorType, method: "onSignInStrongAuthMethodRegistration"
            )
        }
    }

    func test_MFA_deliversExactStateAndMethodsOnceAfterTelemetry() async {
        let state = AwaitingMFAState(
            controller: MSALNativeAuthSignInControllerMock(), scopes: ["scope"], claimsRequestJson: nil,
            continuationToken: "mfa-token", correlationId: correlationId
        )
        let methods = [MSALAuthMethod(id: "phone", challengeType: "oob", channelTargetType: .init(value: "sms"), loginHint: nil)]
        for (_, delivery) in mfaDeliveries(state: state, methods: methods) {
            let delegate = SupportedDelegate()
            var events: [String] = []
            delegate.onMFA = { receivedMethods, receivedState in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(receivedMethods.count, 1)
                XCTAssertTrue(receivedMethods.first === methods.first)
                XCTAssertTrue(receivedState === state)
                events.append("delegate")
            }
            await delivery(delegate) { result in
                guard case .success = result else { return XCTFail("Expected successful MFA delivery") }
                events.append("telemetry")
            }
            XCTAssertEqual(events, ["telemetry", "delegate"])
            XCTAssertTrue(delegate.errors.isEmpty)
        }
    }

    func test_MFA_missingOptionalMethodDeliversSameTypedErrorOnce() async throws {
        let state = AwaitingMFAState(
            controller: MSALNativeAuthSignInControllerMock(), scopes: [], claimsRequestJson: nil,
            continuationToken: "mfa-token", correlationId: correlationId
        )
        for (errorType, delivery) in mfaDeliveries(state: state, methods: []) {
            let delegate = MissingDelegate()
            var telemetryErrors: [MSALNativeAuthError] = []
            await delivery(delegate) { result in
                guard case .failure(let error) = result else { return XCTFail("Expected missing-delegate error") }
                telemetryErrors.append(error)
            }
            try assertMissingMethod(
                delegate: delegate, telemetryErrors: telemetryErrors, errorType: errorType, method: "onSignInAwaitingMFA"
            )
        }
    }

    func test_signInCompleted_returnsExactAccountOrActionableMissingDelegateError() async throws {
        let result = MSALNativeAuthUserAccountResultStub.result
        for (errorType, delivery) in completionDeliveries(result: result) {
            let delegate = SupportedDelegate()
            var events: [String] = []
            delegate.onCompleted = { received in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(received === result)
                events.append("delegate")
            }
            await delivery(delegate) { response in
                guard case .success = response else { return XCTFail("Expected successful completion") }
                events.append("telemetry")
            }
            XCTAssertEqual(events, ["telemetry", "delegate"])
            XCTAssertTrue(delegate.errors.isEmpty)

            let missing = MissingDelegate()
            var telemetryErrors: [MSALNativeAuthError] = []
            await delivery(missing) { response in
                guard case .failure(let error) = response else { return XCTFail("Expected missing-delegate error") }
                telemetryErrors.append(error)
            }
            try assertMissingMethod(
                delegate: missing, telemetryErrors: telemetryErrors, errorType: errorType, method: "onSignInCompleted"
            )
        }
    }

    private func registrationDeliveries(
        state: RegisterStrongAuthState, methods: [MSALAuthMethod]
    ) -> [(MSALNativeAuthError.Type, Delivery)] {
        [
            (SignInStartError.self, { delegate, telemetry in
                await SignInStartDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchJITRequired(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (PasswordRequiredError.self, { delegate, telemetry in
                await SignInPasswordRequiredDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchJITRequired(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (VerifyCodeError.self, { delegate, telemetry in
                await SignInVerifyCodeDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchJITRequired(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (SignInAfterSignUpError.self, { delegate, telemetry in
                await SignInAfterSignUpDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchJITRequired(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (SignInAfterResetPasswordError.self, { delegate, telemetry in
                await SignInAfterResetPasswordDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchJITRequired(authMethods: methods, newState: state, correlationId: self.correlationId)
            })
        ]
    }

    private func mfaDeliveries(
        state: AwaitingMFAState, methods: [MSALAuthMethod]
    ) -> [(MSALNativeAuthError.Type, Delivery)] {
        [
            (SignInStartError.self, { delegate, telemetry in
                await SignInStartDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchAwaitingMFA(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (PasswordRequiredError.self, { delegate, telemetry in
                await SignInPasswordRequiredDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchAwaitingMFA(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (VerifyCodeError.self, { delegate, telemetry in
                await SignInVerifyCodeDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchAwaitingMFA(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (SignInAfterSignUpError.self, { delegate, telemetry in
                await SignInAfterSignUpDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchAwaitingMFA(authMethods: methods, newState: state, correlationId: self.correlationId)
            }),
            (SignInAfterResetPasswordError.self, { delegate, telemetry in
                await SignInAfterResetPasswordDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchAwaitingMFA(authMethods: methods, newState: state, correlationId: self.correlationId)
            })
        ]
    }

    private func completionDeliveries(result: MSALNativeAuthUserAccountResult) -> [(MSALNativeAuthError.Type, Delivery)] {
        [
            (SignInStartError.self, { delegate, telemetry in
                await SignInStartDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchSignInCompleted(result: result, correlationId: self.correlationId)
            }),
            (PasswordRequiredError.self, { delegate, telemetry in
                await SignInPasswordRequiredDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchSignInCompleted(result: result, correlationId: self.correlationId)
            }),
            (VerifyCodeError.self, { delegate, telemetry in
                await SignInVerifyCodeDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchSignInCompleted(result: result, correlationId: self.correlationId)
            }),
            (SignInAfterSignUpError.self, { delegate, telemetry in
                await SignInAfterSignUpDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchSignInCompleted(result: result, correlationId: self.correlationId)
            }),
            (SignInAfterResetPasswordError.self, { delegate, telemetry in
                await SignInAfterResetPasswordDelegateDispatcher(delegate: delegate, telemetryUpdate: telemetry)
                    .dispatchSignInCompleted(result: result, correlationId: self.correlationId)
            })
        ]
    }

    private func assertMissingMethod(
        delegate: MissingDelegate, telemetryErrors: [MSALNativeAuthError], errorType: MSALNativeAuthError.Type, method: String
    ) throws {
        XCTAssertEqual(delegate.errors.count, 1)
        XCTAssertEqual(telemetryErrors.count, 1)
        let error = try XCTUnwrap(delegate.errors.first)
        XCTAssertTrue(error === telemetryErrors.first)
        XCTAssertEqual(ObjectIdentifier(type(of: error)), ObjectIdentifier(errorType))
        XCTAssertTrue(error.isGeneralError)
        XCTAssertFalse(error.isBrowserRequired)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, method))
        XCTAssertEqual(error.errorCodes, [])
        XCTAssertNil(error.errorUri)
    }

    private class MissingDelegate: NSObject, SignInStartDelegate, SignInPasswordRequiredDelegate,
                                   SignInVerifyCodeDelegate, SignInAfterSignUpDelegate, SignInAfterResetPasswordDelegate {
        var errors: [MSALNativeAuthError] = []

        func onSignInStartError(error: SignInStartError) {
            XCTAssertTrue(Thread.isMainThread)
            errors.append(error)
        }

        func onSignInPasswordRequiredError(error: PasswordRequiredError, newState: SignInPasswordRequiredState?) {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(newState)
            errors.append(error)
        }

        func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?) {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(newState)
            errors.append(error)
        }

        func onSignInAfterSignUpError(error: SignInAfterSignUpError) {
            XCTAssertTrue(Thread.isMainThread)
            errors.append(error)
        }

        func onSignInAfterResetPasswordError(error: SignInAfterResetPasswordError) {
            XCTAssertTrue(Thread.isMainThread)
            errors.append(error)
        }
    }

    private final class SupportedDelegate: MissingDelegate {
        var onRegistration: (([MSALAuthMethod], RegisterStrongAuthState) -> Void)?
        var onMFA: (([MSALAuthMethod], AwaitingMFAState) -> Void)?
        var onCompleted: ((MSALNativeAuthUserAccountResult) -> Void)?

        @objc func onSignInStrongAuthMethodRegistration(authMethods: [MSALAuthMethod], newState: RegisterStrongAuthState) {
            onRegistration?(authMethods, newState)
        }

        @objc func onSignInAwaitingMFA(authMethods: [MSALAuthMethod], newState: AwaitingMFAState) {
            onMFA?(authMethods, newState)
        }

        @objc func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
            onCompleted?(result)
        }
    }
}
