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

/// Base type for an action the server can request during a Native Auth V2 (server-driven) flow.
///
/// The SDK reports each step to the app through
/// ``MSALNativeAuthFlowDelegate/onActionRequired(action:flowState:)``. Inspect the concrete
/// subclass to determine which action is required and to read its associated data, e.g.:
///
/// ```swift
/// func onActionRequired(action: MSALNativeAuthAction, flowState: MSALNativeAuthFlowState) {
///     if let action = action as? MSALNativeAuthCodeRequiredAction {
///         // prompt for a code, then flowState.submitCode(...)
///     }
/// }
/// ```
@objcMembers
public class MSALNativeAuthAction: NSObject {

    /// A Swift-only enum projection of the action, for ergonomic pattern matching.
    ///
    /// The action is delivered as a class (so the delegate protocol can be `@objc`), but Swift
    /// callers can `switch` over ``kind`` to destructure the associated data, e.g.:
    ///
    /// ```swift
    /// switch action.kind {
    /// case .codeRequired(let sentTo, _, let codeLength): ...
    /// case .attributesRequired(let attributes): ...
    /// default: ...
    /// }
    /// ```
    public enum Kind {
        case codeRequired(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int)
        case passwordRequired
        case newPasswordRequired
        case attributesRequired(attributes: [MSALNativeAuthRequiredAttribute])
        case attributesInvalid(attributeNames: [String])
        case mfaRequired(authMethods: [MSALAuthMethod])
        case mfaVerificationRequired(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int)
        case strongAuthRegistrationRequired(authMethods: [MSALAuthMethod])
        case strongAuthVerificationRequired(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int)

        /// An unknown/unhandled action. Present only for forward compatibility.
        case unknown
    }

    /// The action expressed as a Swift enum for pattern matching. See ``Kind``.
    public var kind: Kind {
        switch self {
        case let action as MSALNativeAuthCodeRequiredAction:
            return .codeRequired(sentTo: action.sentTo, channel: action.channel, codeLength: action.codeLength)
        case is MSALNativeAuthPasswordRequiredAction:
            return .passwordRequired
        case is MSALNativeAuthNewPasswordRequiredAction:
            return .newPasswordRequired
        case let action as MSALNativeAuthAttributesRequiredAction:
            return .attributesRequired(attributes: action.attributes)
        case let action as MSALNativeAuthAttributesInvalidAction:
            return .attributesInvalid(attributeNames: action.attributeNames)
        case let action as MSALNativeAuthMFARequiredAction:
            return .mfaRequired(authMethods: action.authMethods)
        case let action as MSALNativeAuthMFAVerificationRequiredAction:
            return .mfaVerificationRequired(sentTo: action.sentTo, channel: action.channel, codeLength: action.codeLength)
        case let action as MSALNativeAuthStrongAuthRegistrationRequiredAction:
            return .strongAuthRegistrationRequired(authMethods: action.authMethods)
        case let action as MSALNativeAuthStrongAuthVerificationRequiredAction:
            return .strongAuthVerificationRequired(sentTo: action.sentTo, channel: action.channel, codeLength: action.codeLength)
        default:
            return .unknown
        }
    }
}

/// The server requires the user to verify a one-time code.
/// Continue with ``MSALNativeAuthFlowState/submitCode(_:delegate:)``.
@objcMembers
public class MSALNativeAuthCodeRequiredAction: MSALNativeAuthAction {

    /// The email/phone the code was sent to.
    public let sentTo: String

    /// The channel (email/phone) the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The length of the code required.
    public let codeLength: Int

    init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }
}

/// The server requires the user to enter their password.
/// Continue with ``MSALNativeAuthFlowState/submitPassword(_:delegate:)``.
@objcMembers
public class MSALNativeAuthPasswordRequiredAction: MSALNativeAuthAction {}

/// The server requires the user to enter a new password (self-service password reset).
/// Continue with ``MSALNativeAuthFlowState/submitNewPassword(_:delegate:)``.
@objcMembers
public class MSALNativeAuthNewPasswordRequiredAction: MSALNativeAuthAction {}

/// The server requires additional user attributes.
/// Continue with ``MSALNativeAuthFlowState/submitAttributes(_:delegate:)``.
@objcMembers
public class MSALNativeAuthAttributesRequiredAction: MSALNativeAuthAction {

    /// The attributes the server requires.
    public let attributes: [MSALNativeAuthRequiredAttribute]

    init(attributes: [MSALNativeAuthRequiredAttribute]) {
        self.attributes = attributes
        super.init()
    }
}

/// The server reports that some attributes were invalid and must be corrected.
/// Continue with ``MSALNativeAuthFlowState/submitAttributes(_:delegate:)``.
@objcMembers
public class MSALNativeAuthAttributesInvalidAction: MSALNativeAuthAction {

    /// The names of the attributes that failed validation.
    public let attributeNames: [String]

    init(attributeNames: [String]) {
        self.attributeNames = attributeNames
        super.init()
    }
}

/// The server requires multi-factor authentication; the user must select an auth method.
/// Continue with ``MSALNativeAuthFlowState/selectAuthMethod(_:verificationContact:delegate:)``.
@objcMembers
public class MSALNativeAuthMFARequiredAction: MSALNativeAuthAction {

    /// The authentication methods the user can select.
    public let authMethods: [MSALAuthMethod]

    init(authMethods: [MSALAuthMethod]) {
        self.authMethods = authMethods
        super.init()
    }
}

/// The server sent an MFA challenge; the user must enter the verification code.
/// Continue with ``MSALNativeAuthFlowState/submitChallenge(_:delegate:)``.
@objcMembers
public class MSALNativeAuthMFAVerificationRequiredAction: MSALNativeAuthAction {

    /// The email/phone the code was sent to.
    public let sentTo: String

    /// The channel (email/phone) the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The length of the code required.
    public let codeLength: Int

    init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }
}

/// The server requires strong authentication registration (JIT); the user must select an auth method.
@objcMembers
public class MSALNativeAuthStrongAuthRegistrationRequiredAction: MSALNativeAuthAction {

    /// The authentication methods the user can select.
    public let authMethods: [MSALAuthMethod]

    init(authMethods: [MSALAuthMethod]) {
        self.authMethods = authMethods
        super.init()
    }
}

/// The server sent a JIT challenge; the user must enter the verification code.
/// Continue with ``MSALNativeAuthFlowState/submitChallenge(_:delegate:)``.
@objcMembers
public class MSALNativeAuthStrongAuthVerificationRequiredAction: MSALNativeAuthAction {

    /// The email/phone the code was sent to.
    public let sentTo: String

    /// The channel (email/phone) the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The length of the code required.
    public let codeLength: Int

    init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }
}
