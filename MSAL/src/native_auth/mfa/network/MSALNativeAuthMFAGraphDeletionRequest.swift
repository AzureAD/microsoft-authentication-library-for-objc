// ------------------------------------------------------------------------------
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
// ------------------------------------------------------------------------------

import Foundation

/// Graph deletion configuration and token checks, independent of the MFA operation's mutable state.
internal struct MSALNativeAuthMFAGraphDeletionRequest: Sendable {
    private typealias Failure = MSALNativeAuthMFAError.Reason

    let endpoint: URL
    let tokenParameters: MSALTokenProviderParameters

    init(account: MSALNativeAuthMFAAccountRecord) throws {
        guard let host = account.endpoint.host?.lowercased(),
              host.hasSuffix(".microsoft.com") || host.hasSuffix(".phonefactor.net") else {
            throw Failure.unsupportedDeletionCloud
        }
        guard UUID(uuidString: account.tenantId) != nil, UUID(uuidString: account.objectId) != nil,
              let authority = URL(string: "https://login.microsoftonline.com/" + account.tenantId) else {
            throw Failure.invalidResponse
        }
        tokenParameters = MSALTokenProviderParameters(
            authorityURL: authority,
            scopes: ["https://graph.microsoft.com/UserAuthenticationMethod.ReadWrite"],
            claimsRequestJSON: #"{"access_token":{"amr":{"essential":true,"values":["ngcmfa"]}}}"#,
            tenantId: account.tenantId, objectId: account.objectId, loginHint: account.username,
            correlationId: MSALNativeAuthMFARequestContext.correlationId ?? UUID()
        )
        guard let endpoint = URL(string:
            "https://graph.microsoft.com/v1.0/users/\(account.objectId)/authentication/microsoftAuthenticatorMethods/\(account.id)"
        ) else { throw Failure.invalidResponse }
        try MSALNativeAuthMFAEndpoint.Policy.graphDeletion.validate(endpoint)
        self.endpoint = endpoint
    }

    func validateToken(_ result: MSALTokenProviderResult) throws {
        let parameters = tokenParameters
        guard let tenantId = parameters.tenantId, let objectId = parameters.objectId,
              result.tenantId.caseInsensitiveCompare(tenantId) == .orderedSame,
              result.objectId.caseInsensitiveCompare(objectId) == .orderedSame,
              result.authorityURL.scheme == "https", result.authorityURL.host == parameters.authorityURL.host else {
            throw Failure.deletionAccountMismatch
        }
        let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard !result.accessToken.isEmpty, result.accessToken.utf8.count <= 65_536,
              !result.accessToken.unicodeScalars.contains(where: { forbidden.contains($0) }),
              let expires = result.expiresOn, expires > Date(),
              result.authenticationScheme.caseInsensitiveCompare("Bearer") == .orderedSame,
              result.scopes.contains(where: {
                  $0.caseInsensitiveCompare("UserAuthenticationMethod.ReadWrite") == .orderedSame
                      || $0.caseInsensitiveCompare(parameters.scopes[0]) == .orderedSame
              }) else { throw Failure.invalidDeletionToken }
    }
}
