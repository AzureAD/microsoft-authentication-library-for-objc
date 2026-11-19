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

/// Sign-up found an existing account and requires its current password, not a new password.
///
/// Use the inherited `submitPassword(_:delegate:)` to continue sign-in, including MFA or enrollment.
/// An invalid password can be retried on this state. The proposed sign-up password is not submitted
/// automatically. Callbacks use the `signIn` scenario.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthExistingAccountPasswordRequiredState: MSALNativeAuthPasswordRequiredState {

    public override var description: String {
        return "existingAccountPasswordRequired"
    }
}

/// Handles existing-account password collection discovered during V2 sign-up.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public protocol MSALNativeAuthExistingAccountPasswordRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// Collect the existing account's current password and submit it through the state.
    /// - Parameters:
    ///   - state: The state used to submit the existing account's password.
    ///   - scenario: Always `signIn`, even though the flow started with sign-up.
    @MainActor func onExistingAccountPasswordRequired(
        state: MSALNativeAuthExistingAccountPasswordRequiredState,
        scenario: MSALNativeAuthFlowScenario
    )
}
