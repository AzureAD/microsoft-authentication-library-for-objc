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

/// Protocol that defines the methods of a ResetPasswordStart delegate
@objc
public protocol ResetPasswordStartDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onResetPasswordStartError(error: ResetPasswordStartError)

    /// Notifies the delegate that a verification code is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onResetPasswordStartError(error:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onResetPasswordCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
}

/// Protocol that defines the methods of a ResetPasswordVerifyCode delegate
@objc
public protocol ResetPasswordVerifyCodeDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?)

    /// Notifies the delegate that a password is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onResetPasswordVerifyCodeError(error:newState:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onPasswordRequired(newState: ResetPasswordRequiredState)
}

/// Protocol that defines the methods of a ResetPasswordResendCode delegate
@objc
public protocol ResetPasswordResendCodeDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeRequiredState?)

    /// Notifies the delegate that a verification code is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onResetPasswordResendCodeError(error:newState:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onResetPasswordResendCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
}

/// Protocol that defines the methods of a ResetPasswordRequired delegate
@objc
public protocol ResetPasswordRequiredDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?)

    /// Notifies the delegate that the reset password operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onResetPasswordRequiredError(error:newState:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onResetPasswordCompleted(newState: SignInAfterResetPasswordState)
}
