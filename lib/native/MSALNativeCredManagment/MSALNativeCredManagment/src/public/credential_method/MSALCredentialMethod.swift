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

/// Base class for all credential methods.
///
/// Each credential type (passkey, phone, password, etc.) is represented
/// by a concrete subclass. New credential types can be added by subclassing
/// without modifying existing classes (Open/Closed Principle).
///
/// Do not instantiate `MSALCredentialMethod` directly — use the appropriate subclass.
@objcMembers
open class MSALCredentialMethod: NSObject {

    /// Unique identifier of the credential method.
    public let id: String

    /// The type identifier string (e.g., "passkey", "phone", "password").
    public let credentialType: String

    /// Display-friendly name or hint (e.g., masked phone "+1 ***-***-1234").
    public let displayName: String?

    /// Whether this is the default/primary method.
    public let isDefault: Bool

    /// Timestamp of when this method was registered.
    public let createdAt: Date?

    /// Subclasses must override to provide type-specific initialization from server response.
    ///
    /// - Parameters:
    ///   - id: Unique identifier from the server.
    ///   - credentialType: The type string for this credential.
    ///   - displayName: A user-facing display name or hint.
    ///   - isDefault: Whether this is the user's default method.
    ///   - createdAt: The creation timestamp.
    public init(
        id: String,
        credentialType: String,
        displayName: String?,
        isDefault: Bool,
        createdAt: Date?
    )
    {
        self.id = id
        self.credentialType = credentialType
        self.displayName = displayName
        self.isDefault = isDefault
        self.createdAt = createdAt
        super.init()
    }
}
