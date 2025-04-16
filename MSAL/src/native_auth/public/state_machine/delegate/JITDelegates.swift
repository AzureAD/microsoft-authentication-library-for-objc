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

@objc
public protocol RegisterStrongAuthChallengeDelegate {

    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///     - error: An error object indicating why the operation failed.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onRegisterStrongAuthChallengeError(error: RegisterStrongAuthChallengeError, newState: RegisterStrongAuthState?)

    /// Notifies the delegate that a verification is required from the user to continue.
    /// - Note: If a flow requires this optional method and it is not implemented,
    ///         then ``onSignInRegisterStrongAuthChallengeError(error::newState:)`` will be called.
    /// - Parameter: result: An object representing the new state of the flow with follow on methods.
    @MainActor @objc optional func onRegisterStrongAuthVerificationRequired(result: MSALNativeAuthRegisterStrongAuthVerificationRequiredResult)

    //TODO: I think this needs to be removed
    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented,
    ///         then ``onSignInRegisterStrongAuthChallengeError(error:newState:)`` will be called.
    /// - Parameter result: An object representing the signed in user account.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}

@objc
public protocol RegisterStrongAuthSubmitChallengeDelegate {

    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameters:
    ///     - error: An error object indicating why the operation failed.
    ///     - newState: An object representing the new state of the flow with follow on methods.
    @MainActor func onRegisterStrongAuthSubmitChallengeError(
        error: RegisterStrongAuthSubmitChallengeError,
        newState: RegisterStrongAuthVerificationRequiredState?
    )

    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented,
    ///         then ``onSignInRegisterStrongAuthChallengeError(error:newState:)`` will be called.
    /// - Parameter result: An object representing the signed in user account.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}
