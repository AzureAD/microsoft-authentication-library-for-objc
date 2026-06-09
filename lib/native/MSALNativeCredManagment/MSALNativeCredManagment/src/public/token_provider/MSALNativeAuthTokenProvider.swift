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
import MSAL

/// A built-in token provider that uses MSAL's web-based interactive flow to acquire tokens.
///
/// On first call, it presents a web view for interactive sign-in. On subsequent calls,
/// it attempts silent token acquisition using the cached account, falling back to interactive
/// if the silent attempt fails with `MSALErrorInteractionRequired`.
///
/// Usage:
/// ```swift
/// let tokenProvider = try MSALNativeAuthTokenProvider(clientId: "your-client-id")
/// config.tokenProvider = tokenProvider
/// ```
@objcMembers
public class MSALNativeAuthTokenProvider: NSObject, MSALNativeCredentialManagementTokenProvider
{
    /// Initialize with a client ID. Uses the default MSAL authority.
    ///
    /// - Parameter clientId: The application (client) ID registered in the identity platform.
    /// - Throws: If the MSAL configuration is invalid.
    public init(clientId: String) throws
    {
        super.init()
        fatalError("Not implemented — stub only")
    }

    /// Retrieve an access token using MSAL web flow.
    ///
    /// Attempts silent acquisition first. If no cached account exists or interaction is required,
    /// falls back to interactive web view sign-in.
    ///
    /// - Parameters:
    ///   - scopes: The scopes required by the credential management operation.
    ///   - completionBlock: Called exactly once with the access token on success,
    ///     or nil and an error on failure.
    public func getAccessToken(
        scopes: [String],
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    )
    {
        fatalError("Not implemented — stub only")
    }

    /// Clear the cached account so the next token request triggers interactive sign-in.
    public func signOut()
    {
        fatalError("Not implemented — stub only")
    }
}
