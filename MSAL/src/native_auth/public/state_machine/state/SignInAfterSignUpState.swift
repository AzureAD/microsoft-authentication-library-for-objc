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

/// An object of this type is created when a user has signed up successfully.
@objcMembers public class SignInAfterSignUpState: NSObject {

    let controller: MSALNativeAuthSignInControlling
    let username: String
    let continuationToken: String?

    init(controller: MSALNativeAuthSignInControlling, username: String, continuationToken: String?) {
        self.username = username
        self.continuationToken = continuationToken
        self.controller = controller
    }

    /// Sign in the user that signed up.
    /// - Parameters:
    ///   - scopes: Optional. Permissions you want included in the access token received after sign in flow has completed.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Sign In flow.
    public func signIn(
        scopes: [String]? = nil,
        correlationId: UUID? = nil,
        delegate: SignInAfterSignUpDelegate
    ) {
        Task {
            let controllerResult = await signInInternal(scopes: scopes, correlationId: correlationId)

            switch controllerResult {
            case .success(let accountResult):
                await delegate.onSignInCompleted(result: accountResult)
            case .failure(let error):
                await delegate.onSignInAfterSignUpError(error: error)
            }
        }
    }
}
