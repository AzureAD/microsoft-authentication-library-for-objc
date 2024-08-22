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

/// Protocol that defines the methods of a MFASendChallenge delegate
@objc
public protocol MFASendChallengeDelegate {

    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///     - error: An error object indicating why the operation failed.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onMFASendChallengeError(error: MFASendChallengeError, newState: MFARequiredState?)

    /// Notifies the delegate that a verification is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onMFASendChallengeError(error:)`` will be called.
    /// - Parameters:
    ///   - newState: An object representing the new state of the flow with follow on methods.
    ///   - sentTo: The email/phone number that the code was sent to.
    ///   - channelTargetType: The channel (email/phone) the code was sent through.
    ///   - codeLength: The length of the code required.
    @MainActor @objc optional func onMFASendChallengeVerificationRequired(
        newState: MFARequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int)

    /// Notifies the delegate that the list of authentication methods is now available.
    /// The user is required to choose an authentication method and then proceed with the "newState" to advance in the MFA process.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onMFASendChallengeError(error:)`` will be called.
    /// - Parameters:
    ///     - authMethods: list of authentication method
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onMFASendChallengeSelectionRequired(authMethods: [MSALAuthMethod], newState: MFARequiredState)
}

/// Protocol that defines the methods of a MFAGetAuthMethodsDelegate delegate
@objc
public protocol MFAGetAuthMethodsDelegate {

    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///     - error: An error object indicating why the operation failed.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onMFAGetAuthMethodsError(error: MFAGetAuthMethodsError, newState: MFARequiredState?)

    /// Notifies the delegate that the list of authentication methods is now available.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onMFAGetAuthMethodsError(error:)`` will be called.
    /// - Parameters:
    ///     - authMethods: list of authentication method
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onMFAGetAuthMethodsSelectionRequired(authMethods: [MSALAuthMethod], newState: MFARequiredState)
}

/// Protocol that defines the methods of a MFAGetAuthMethodsDelegate delegate
@objc
public protocol MFASubmitChallengeDelegate {

    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///     - error: An error object indicating why the operation failed.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onMFASubmitChallengeError(error: MFASubmitChallengeError, newState: MFARequiredState?)

    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onMFASubmitChallengeError(error:newState:)`` will be called.
    /// - Parameter result: An object representing the signed in user account.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}
