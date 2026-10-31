//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

import Foundation

/// Supplies delegated tokens independently of the feature or authentication experience using them.
/// Implementations may use native authentication or browser-based MSAL. Reusing a provider does not
/// imply reusing a token: honor each request's authority, account, scopes and claims.
/// Marshal UI to the main actor and never present UI when `allowsInteraction` is false.
/// Throw on cancellation, interaction required, unsupported requirements or acquisition failure;
/// never silently discard claims or substitute a different account. Do not log requests or results.
public protocol MSALTokenProvider: Sendable {
    func getAccessToken(parameters: MSALTokenProviderParameters) async throws -> MSALTokenProviderResult
}

/// Immutable token requirements supplied by the consuming feature, not browser presentation settings.
public final class MSALTokenProviderParameters: Sendable {
    public let authorityURL: URL
    public let scopes: [String]
    /// OIDC claims JSON. Parse a fresh MSALClaimsRequest for acquisition; do not modify returned tokens.
    public let claimsRequestJSON: String?
    /// Expected account identity when specified. A login hint alone is not proof of identity.
    public let tenantId: String?
    public let objectId: String?
    /// Optional personal information for sign-in UI. Do not log it.
    public let loginHint: String?
    public let allowsInteraction: Bool
    public let correlationId: UUID

    public init(
        authorityURL: URL,
        scopes: [String],
        claimsRequestJSON: String? = nil,
        tenantId: String? = nil,
        objectId: String? = nil,
        loginHint: String? = nil,
        allowsInteraction: Bool = true,
        correlationId: UUID = UUID()
    ) {
        self.authorityURL = authorityURL
        self.scopes = scopes
        self.claimsRequestJSON = claimsRequestJSON
        self.tenantId = tenantId
        self.objectId = objectId
        self.loginHint = loginHint
        self.allowsInteraction = allowsInteraction
        self.correlationId = correlationId
    }
}

/// Token and account metadata mapped from the authentication library's result.
/// Native providers need not construct an MSALResult. Do not infer identity by decoding an access token,
/// copy expected request identity into the result, persist this result, or log its contents.
/// Consumers validate required metadata; the resource server validates the token and authorization.
public final class MSALTokenProviderResult: Sendable {
    public let accessToken: String
    public let expiresOn: Date?
    public let scopes: [String]
    public let tenantId: String
    public let objectId: String
    public let authorityURL: URL
    public let authenticationScheme: String

    public init(
        accessToken: String,
        expiresOn: Date?,
        scopes: [String],
        tenantId: String,
        objectId: String,
        authorityURL: URL,
        authenticationScheme: String
    ) {
        self.accessToken = accessToken
        self.expiresOn = expiresOn
        self.scopes = scopes
        self.tenantId = tenantId
        self.objectId = objectId
        self.authorityURL = authorityURL
        self.authenticationScheme = authenticationScheme
    }
}
