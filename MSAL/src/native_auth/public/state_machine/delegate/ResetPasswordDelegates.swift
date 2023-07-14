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

@objc
public protocol ResetPasswordStartDelegate {
    /// Tells the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating how the operation failed.
    @MainActor func onResetPasswordError(error: ResetPasswordStartError)

    /// Tells the delegate that a verification code is required from the user to continue.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: the length of the code required.
    @MainActor func onResetPasswordCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
}

@objc
public protocol ResetPasswordVerifyCodeDelegate {
    /// Tells the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating how the operation failed.
    @MainActor func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?)

    /// Tells the delegate that a password is required from the user to continue.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onPasswordRequired(newState: ResetPasswordRequiredState)
}

@objc
public protocol ResetPasswordResendCodeDelegate {
    /// Tells the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating how the operation failed.
    @MainActor func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeRequiredState?)

    /// Tells the delegate that a verification code is required from the user to continue.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: the length of the code required.
    @MainActor func onResetPasswordResendCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
}

@objc
public protocol ResetPasswordRequiredDelegate {
    /// Tells the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating how the operation failed.
    @MainActor func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?)

    /// Tells the delegate that the reset password operation completed successfully.
    @MainActor func onResetPasswordCompleted()
}
