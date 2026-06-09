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

extension MSALRegisterMethods
{
    /// Registers a new passkey (FIDO2/WebAuthn) credential.
    ///
    /// This single call handles the entire flow:
    /// 1. Requests creation options from the server.
    /// 2. Presents the system passkey sheet to the user.
    /// 3. Submits the attestation back to the server.
    ///
    /// - Parameter params: Parameters including the presentation anchor and optional display name.
    /// - Returns: A `Result` containing the registration result or an error.
    ///
    /// Example:
    /// ```swift
    /// let params = MSALRegisterPasskeyParams(
    ///     presentationAnchor: view.window!,
    ///     displayName: "My iPhone"
    /// )
    /// let result = await client.register.passkey(params: params)
    /// switch result {
    /// case .success(.completed(let method)):
    ///     print("Registered: \(method.id)")
    /// case .failure(let error):
    ///     print("Failed: \(error.message ?? "")")
    /// }
    /// ```
    public func passkey(
        params: MSALRegisterPasskeyParams
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        fatalError("Not implemented — stub only")
    }
}
