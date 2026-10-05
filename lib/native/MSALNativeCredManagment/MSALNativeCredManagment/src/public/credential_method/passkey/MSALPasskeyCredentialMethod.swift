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

extension MSALCredentialType {
    /// Passkey (FIDO2/WebAuthn) credential type.
    public static let passkey = MSALCredentialType("fido")
}

/// Represents a passkey (FIDO2/WebAuthn) credential method.
@objcMembers
public class MSALPasskeyCredentialMethod: MSALCredentialMethod {

    /// The base64-encoded credential ID from WebAuthn registration.
    public let credentialID: String?

    /// The AAGUID of the authenticator that created this passkey.
    public let aaguid: String?

    public init(
        displayName: String?,
        credentialID: String?,
        aaguid: String? = nil
    )
    {
        self.credentialID = credentialID
        self.aaguid = aaguid
        super.init(
            id: "",
            credentialType: .passkey,
            displayName: displayName,
            createdAt: nil
        )
    }

    /// Internal initializer used by the SDK when hydrating from server responses.
    internal init(
        id: String,
        displayName: String?,
        createdAt: Date?,
        credentialID: String?,
        aaguid: String? = nil
    )
    {
        self.credentialID = credentialID
        self.aaguid = aaguid
        super.init(
            id: id,
            credentialType: .passkey,
            displayName: displayName,
            createdAt: createdAt
        )
    }
}
