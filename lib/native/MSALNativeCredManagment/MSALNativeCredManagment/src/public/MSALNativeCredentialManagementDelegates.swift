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

// MARK: - List Credential Methods Delegate

/// Protocol that defines the delegate methods for listing credential methods.
@objc public protocol MSALCredentialMethodsListDelegate {

    /// Notifies the delegate that the list operation completed successfully.
    /// - Parameter methods: The array of credential methods registered for the user.
    @MainActor func onCredentialMethodsListCompleted(methods: [MSALCredentialMethod])

    /// Notifies the delegate that the list operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onCredentialMethodsListError(error: MSALNativeCredentialManagementError)
}

// MARK: - Register Credential Method Delegate

/// Protocol that defines the delegate methods for registering a credential method.
@objc public protocol MSALCredentialMethodRegisterDelegate {

    /// Notifies the delegate that the registration completed successfully.
    /// - Parameter method: The newly registered credential method.
    @MainActor func onCredentialMethodRegistrationCompleted(method: MSALCredentialMethod)

    /// Notifies the delegate that the registration resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onCredentialMethodRegistrationError(error: MSALNativeCredentialManagementError)

    /// Notifies the delegate that a challenge verification is required to complete registration.
    ///
    /// The user must provide a verification code (e.g., OTP sent to the new email/phone).
    /// Call `state.submitChallenge(code:delegate:)` to continue.
    ///
    /// - Note: If this optional method is not implemented, `onCredentialMethodRegistrationError(error:)` will be called instead.
    /// - Parameter state: The challenge state containing information about the sent challenge and methods to respond.
    @MainActor @objc optional func onCredentialMethodChallengeRequired(
        state: MSALCredentialMethodChallengeState
    )
}

// MARK: - Delete Credential Method Delegate

/// Protocol that defines the delegate methods for deleting a credential method.
@objc public protocol MSALCredentialMethodDeleteDelegate {

    /// Notifies the delegate that the delete operation completed successfully.
    @MainActor func onCredentialMethodDeleteCompleted()

    /// Notifies the delegate that the delete operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onCredentialMethodDeleteError(error: MSALNativeCredentialManagementError)
}
