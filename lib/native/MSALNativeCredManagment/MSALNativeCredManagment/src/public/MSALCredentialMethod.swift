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

/// Represents a single credential method registered by the user.
///
/// Instances of this class are returned by `MSALNativeCredentialMethodsClient` when
/// listing or registering credential methods.
@objcMembers
public class MSALCredentialMethod: NSObject {

    /// Unique identifier of the credential method.
    public let id: String

    /// The type of credential (e.g., "password", "email", "phone", "passkey").
    public let credentialType: String

    /// Display-friendly name or hint (e.g., masked email "j***@contoso.com").
    public let displayName: String?

    /// Whether this is the default/primary method.
    public let isDefault: Bool

    /// Timestamp of when this method was registered.
    public let createdAt: Date?

    /// Additional metadata associated with this credential method.
    public let metadata: [String: String]?

    internal init(
        id: String,
        credentialType: String,
        displayName: String?,
        isDefault: Bool,
        createdAt: Date?,
        metadata: [String: String]?
    )
    {
        self.id = id
        self.credentialType = credentialType
        self.displayName = displayName
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.metadata = metadata
        super.init()
    }
}
