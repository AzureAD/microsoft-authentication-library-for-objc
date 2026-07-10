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

/// Base type for states the server can request during a Native Auth V2 (server-driven) flow.
///
/// In V2 the server drives the flow: at each step the SDK reports a concrete
/// ``MSALNativeAuthState`` subclass through its dedicated ``MSALNativeAuthFlowDelegate`` callback
/// (e.g. ``MSALNativeAuthFlowDelegate/onCodeRequired(state:)``). The app then continues the flow by
/// calling the method(s) exposed on that concrete state — each state exposes only the
/// continuations valid for its step, so invalid calls are impossible.
///
/// This is an abstract base class — the SDK always hands back one of its concrete subclasses to the
/// matching state-specific delegate callback, so apps never need to downcast the state.
@objcMembers
public class MSALNativeAuthState: NSObject {

    /// Opaque continuation context for the current step (server continuation token + resolved links).
    /// Injected by the SDK before the state is handed to the app.
    var continuation: MSALNativeAuthV2ContinuationState!

    /// The internal controller that performs the network operations for this flow.
    /// Injected by the SDK before the state is handed to the app.
    var controller: MSALNativeAuthV2FlowControlling!

    /// Injects the continuation context and controller that let this state advance the flow.
    func inject(continuation: MSALNativeAuthV2ContinuationState, controller: MSALNativeAuthV2FlowControlling) {
        self.continuation = continuation
        self.controller = controller
    }

    /// Spawns the controller operation and routes the resulting response back to the delegate.
    func run(
        delegate: MSALNativeAuthFlowDelegate,
        operation: @escaping (MSALNativeAuthV2FlowControlling) async -> MSALNativeAuthV2FlowControllerResponse
    ) {
        let controller = self.controller
        Task {
            guard let controller else { return }
            let response = await operation(controller)
            let dispatcher = MSALNativeAuthFlowResponseDispatcher()
            await dispatcher.dispatch(response, delegate: delegate)
        }
    }
}

/// The server requires the user to verify a one-time code.
/// Continue with ``submitCode(_:delegate:)`` or request a new code with ``resendCode(delegate:)``.
@objcMembers
public class MSALNativeAuthCodeRequiredState: MSALNativeAuthState {

    /// A masked destination the code was sent to (e.g. a partially obfuscated email).
    public let sentTo: String

    /// The channel the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The expected length of the code.
    public let codeLength: Int

    public init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }

    /// Submit a one-time verification code.
    public func submitCode(_ code: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitCode(code, continuation: continuation!)
        }
    }

    /// Request the server to resend the one-time code.
    public func resendCode(delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.resendCode(continuation: continuation!)
        }
    }

    public override var description: String {
        return "codeRequired (sentTo: \(sentTo), length: \(codeLength))"
    }
}

/// The server requires the user to enter their password.
/// Continue with ``submitPassword(_:delegate:)``.
@objcMembers
public class MSALNativeAuthPasswordRequiredState: MSALNativeAuthState {

    /// Submit a password (sign in / sign up).
    public func submitPassword(_ password: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitPassword(password, continuation: continuation!)
        }
    }

    public override var description: String {
        return "passwordRequired"
    }
}

/// The server requires the user to enter a new password (self-service password reset).
/// Continue with ``submitNewPassword(_:delegate:)``.
@objcMembers
public class MSALNativeAuthNewPasswordRequiredState: MSALNativeAuthState {

    /// Submit a new password (self-service password reset).
    public func submitNewPassword(_ password: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitNewPassword(password, continuation: continuation!)
        }
    }

    public override var description: String {
        return "newPasswordRequired"
    }
}

/// The server requires additional user attributes.
/// Continue with ``submitAttributes(_:delegate:)``.
@objcMembers
public class MSALNativeAuthAttributesRequiredState: MSALNativeAuthState {

    /// The attributes the server requires.
    public let attributes: [MSALNativeAuthRequiredAttribute]

    public init(attributes: [MSALNativeAuthRequiredAttribute]) {
        self.attributes = attributes
        super.init()
    }

    /// Submit user attributes (sign up).
    public func submitAttributes(_ attributes: [String: Any], delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitAttributes(attributes, continuation: continuation!)
        }
    }

    public override var description: String {
        return "attributesRequired (\(attributes.map { $0.name }.joined(separator: ", ")))"
    }
}

/// The server reports that some attributes were invalid and must be corrected.
/// Continue with ``submitAttributes(_:delegate:)``.
@objcMembers
public class MSALNativeAuthAttributesInvalidState: MSALNativeAuthState {

    /// The names of the attributes that were invalid.
    public let attributeNames: [String]

    public init(attributeNames: [String]) {
        self.attributeNames = attributeNames
        super.init()
    }

    /// Resubmit the corrected user attributes (sign up).
    public func submitAttributes(_ attributes: [String: Any], delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitAttributes(attributes, continuation: continuation!)
        }
    }

    public override var description: String {
        return "attributesInvalid (\(attributeNames.joined(separator: ", ")))"
    }
}

/// The server requires multi-factor authentication; the user must select an auth method.
/// Continue with ``selectAuthMethod(_:verificationContact:delegate:)``.
@objcMembers
public class MSALNativeAuthMFARequiredState: MSALNativeAuthState {

    /// The authentication methods available for selection.
    public let authMethods: [MSALAuthMethod]

    public init(authMethods: [MSALAuthMethod]) {
        self.authMethods = authMethods
        super.init()
    }

    /// Select an authentication method for MFA.
    public func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        run(delegate: delegate) { [continuation] controller in
            await controller.selectAuthMethod(method, verificationContact: verificationContact, continuation: continuation!)
        }
    }

    /// Select an authentication method for MFA, without an explicit verification contact.
    public func selectAuthMethod(_ method: MSALAuthMethod, delegate: MSALNativeAuthFlowDelegate) {
        selectAuthMethod(method, verificationContact: nil, delegate: delegate)
    }

    public override var description: String {
        return "mfaRequired"
    }
}

/// The server sent an MFA challenge; the user must enter the verification code.
/// Continue with ``submitChallenge(_:delegate:)``.
@objcMembers
public class MSALNativeAuthMFAVerificationRequiredState: MSALNativeAuthState {

    /// A masked destination the code was sent to (e.g. a partially obfuscated email).
    public let sentTo: String

    /// The channel the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The expected length of the code.
    public let codeLength: Int

    public init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }

    /// Submit the MFA challenge response.
    public func submitChallenge(_ challenge: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitChallenge(challenge, continuation: continuation!)
        }
    }

    public override var description: String {
        return "mfaVerificationRequired (sentTo: \(sentTo), length: \(codeLength))"
    }
}

/// The server requires strong authentication registration (JIT); the user must select an auth method.
/// Continue with ``selectAuthMethod(_:verificationContact:delegate:)``.
@objcMembers
public class MSALNativeAuthStrongAuthRegistrationRequiredState: MSALNativeAuthState {

    /// The authentication methods available for registration.
    public let authMethods: [MSALAuthMethod]

    public init(authMethods: [MSALAuthMethod]) {
        self.authMethods = authMethods
        super.init()
    }

    /// Select an authentication method for strong-auth registration.
    public func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        run(delegate: delegate) { [continuation] controller in
            await controller.selectAuthMethod(method, verificationContact: verificationContact, continuation: continuation!)
        }
    }

    /// Select an authentication method for strong-auth registration, without an explicit
    /// verification contact.
    public func selectAuthMethod(_ method: MSALAuthMethod, delegate: MSALNativeAuthFlowDelegate) {
        selectAuthMethod(method, verificationContact: nil, delegate: delegate)
    }

    public override var description: String {
        return "strongAuthRegistrationRequired"
    }
}

/// The server sent a JIT challenge; the user must enter the verification code.
/// Continue with ``submitChallenge(_:delegate:)``.
@objcMembers
public class MSALNativeAuthStrongAuthVerificationRequiredState: MSALNativeAuthState {

    /// A masked destination the code was sent to (e.g. a partially obfuscated email).
    public let sentTo: String

    /// The channel the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The expected length of the code.
    public let codeLength: Int

    public init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }

    /// Submit the strong-auth (JIT) challenge response.
    public func submitChallenge(_ challenge: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitChallenge(challenge, continuation: continuation!)
        }
    }

    public override var description: String {
        return "strongAuthVerificationRequired (sentTo: \(sentTo), length: \(codeLength))"
    }
}
