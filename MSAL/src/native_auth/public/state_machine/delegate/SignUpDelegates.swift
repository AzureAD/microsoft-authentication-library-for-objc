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

/// Protocol that defines the methods of a SignUpStart delegate
@objc
public protocol SignUpStartDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onSignUpStartError(error: SignUpStartError)

    /// Notifies the delegate that a verification code is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpStartError(error:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onSignUpCodeRequired(newState: SignUpCodeRequiredState,
                                                        sentTo: String,
                                                        channelTargetType: MSALNativeAuthChannelType,
                                                        codeLength: Int)

    /// Notifies the delegate that invalid attributes were sent.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpStartError(error:)`` will be called.
    /// - Parameter attributeNames: List of attribute names that failed validation.
    @MainActor @objc optional func onSignUpAttributesInvalid(attributeNames: [String])
}

/// Protocol that defines the methods of a SignUpVerifyCode delegate
@objc
public protocol SignUpVerifyCodeDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onSignUpVerifyCodeError(error: VerifyCodeError, newState: SignUpCodeRequiredState?)

    /// Notifies the delegate that attributes are required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpVerifyCodeError(error:newState:)`` will be called.
    /// - Parameters:
    ///   - attributes: List of required attributes.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState)

    /// Notifies the delegate that a password is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpVerifyCodeError(error:newState:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpPasswordRequired(newState: SignUpPasswordRequiredState)

    /// Notifies the delegate that the sign up operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpVerifyCodeError(error:newState:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpCompleted(newState: SignInAfterSignUpState)
}

/// Protocol that defines the methods of a SignUpResendCode delegate
@objc
public protocol SignUpResendCodeDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onSignUpResendCodeError(error: ResendCodeError, newState: SignUpCodeRequiredState?)

    /// Notifies the delegate that a verification code is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpResendCodeError(error:newState:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onSignUpResendCodeCodeRequired(
        newState: SignUpCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
}

/// Protocol that defines the methods of a SignUpPasswordRequired delegate
@objc
public protocol SignUpPasswordRequiredDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onSignUpPasswordRequiredError(error: PasswordRequiredError, newState: SignUpPasswordRequiredState?)

    /// Notifies the delegate that attributes are required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpPasswordRequiredError(error:newState:)`` will be called.
    /// - Parameters:
    ///   - attributes: List of required attributes.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState)

    /// Notifies the delegate that the sign up operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpPasswordRequiredError(error:newState:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpCompleted(newState: SignInAfterSignUpState)
}

/// Protocol that defines the methods of a SignUpAttributesRequired delegate
@objc
public protocol SignUpAttributesRequiredDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onSignUpAttributesRequiredError(error: AttributesRequiredError)

    /// Notifies the delegate that there are some required attributes to be sent.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpAttributesRequiredError(error:)`` will be called.
    /// - Parameters:
    ///     - attributes:  List of required attributes.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState)

    /// Notifies the delegate that invalid attributes were sent.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpAttributesRequiredError(error:)`` will be called.
    /// - Parameters:
    ///     - attributeNames: List of attribute names that failed validation.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpAttributesInvalid(attributeNames: [String], newState: SignUpAttributesRequiredState)

    /// Notifies the delegate that the sign up operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignUpAttributesRequiredError(error:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignUpCompleted(newState: SignInAfterSignUpState)
}
