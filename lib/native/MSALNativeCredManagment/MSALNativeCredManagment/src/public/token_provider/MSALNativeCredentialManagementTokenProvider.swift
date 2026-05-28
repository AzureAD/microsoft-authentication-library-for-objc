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

/// Completion block type for token retrieval.
public typealias MSALNativeCredentialManagementTokenCompletionBlock = @convention(block) (String?, Error?) -> Void

/// Protocol for providing access tokens to the credential management client.
///
/// Implement this protocol to supply access tokens for credential management API calls.
/// - P0: Provide a custom implementation that calls your own backend.
/// - P1: Use the built-in `MSALNativeAuthTokenProvider` that wraps MSAL Native Auth.
@objc public protocol MSALNativeCredentialManagementTokenProvider: NSObjectProtocol {

    /// Retrieve an access token suitable for calling the credential management API.
    ///
    /// - Important: `completionBlock` **must always be called**, regardless of whether a token is available.
    ///   - On success, call `completionBlock(accessToken, nil)`.
    ///   - On failure, call `completionBlock(nil, error)`.
    ///
    /// - Parameters:
    ///   - scopes: The scopes required by the credential management operation.
    ///   - completionBlock: Must be called with an access token string on success, or nil and an error on failure.
    func getAccessToken(
        scopes: [String],
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    )
}
