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

/// Protocol that defines the methods of a SignInAfterSignUp delegate
@objc
public protocol SignInAfterSignUpDelegate {
    /// Notifies the delegate that the operation resulted in an error.
    /// - Parameter error: An error object indicating why the operation failed.
    @MainActor func onSignInAfterSignUpError(error: SignInAfterSignUpError)

    /// Notifies the delegate that the sign in operation completed successfully.
    /// - Note: If a flow requires this optional method and it is not implemented, then ``onSignInAfterSignUpError(error:)`` will be called.
    /// - Parameter result: An object representing the signed in user account.
    @MainActor @objc optional func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
}
