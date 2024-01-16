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

/// Protocol that defines the methods of a SignInStart delegate
@objc
public protocol SignInStartDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onSignInStartError(error: SignInStartError)

    /// Notifies the delegate that a verification code is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInStartError(error:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onSignInCodeRequired(newState: SignInCodeRequiredState,
                                                        sentTo: String,
                                                        channelTargetType: MSALNativeAuthChannelType,
                                                        codeLength: Int)

    /// Notifies the delegate that a password is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInStartError(error:)`` will be called.
    /// - Parameter newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onSignInPasswordRequired(newState: SignInPasswordRequiredState)

    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Parameter result: An object representing the signed in user account.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInStartError(error:)`` will be called.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}

/// Protocol that defines the methods of a SignInPasswordRequired delegate
@objc
public protocol SignInPasswordRequiredDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onSignInPasswordRequiredError(error: PasswordRequiredError, newState: SignInPasswordRequiredState?)

    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInPasswordRequiredError(error:newState:)`` will be called.
    /// - Parameter result: An object representing the signed in user account.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}

/// Protocol that defines the methods of a SignInResendCode delegate
@objc
public protocol SignInResendCodeDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onSignInResendCodeError(error: ResendCodeError, newState: SignInCodeRequiredState?)

    /// Notifies the delegate that a verification code is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInResendCodeError(error:newState:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onSignInResendCodeCodeRequired(newState: SignInCodeRequiredState,
                                                                  sentTo: String,
                                                                  channelTargetType: MSALNativeAuthChannelType,
                                                                  codeLength: Int)
}

/// Protocol that defines the methods of a SignInVerifyCode delegate
@objc
public protocol SignInVerifyCodeDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///   - error: An error object indicating why the operation failed.
    ///   - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?)

    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInVerifyCodeError(error:newState:)`` will be called.
    /// - Parameter result: An object representing the signed in user account.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}
