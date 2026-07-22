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

/// Internal continuation context carried by a ``MSALNativeAuthFlowInternalState``.
///
/// Holds the opaque server `continuation_token` and the resolved `_links` hrefs
/// the SDK must follow to advance the server-driven flow.
struct MSALNativeAuthFlowContinuationState {
    let flowScenario: MSALNativeAuthFlowScenario
    let continuationToken: String
    /// Resolved `_links` keyed by relation (e.g. "verify", "resend", "update", "poll", "continue",
    /// "challenge", "enroll", "activate", "submitAttributes").
    let links: [String: URL]
    /// Resolved per-auth-method action links keyed by auth-method id (MFA `challenge` / JIT `enroll`).
    /// Separate from ``links`` because it uses a different key space (method ids, not relations).
    let methodLinks: [String: URL]
    let username: String?
    let sentToHint: String?
    let codeLength: Int?
    let authMethods: [MSALAuthMethod]
    /// Scopes (caller-requested merged with the default OIDC scopes) to request on the final
    /// `/token` exchange. Threaded through every step.
    let scopes: [String]
    /// Values supplied by the app at sign-up start (keyed by attribute id, e.g. "email"/"password")
    /// that the SDK submits automatically when the server issues a `collectAttributes` request for
    /// them. Deliberately kept internal so the app never sees them again; must never be logged or
    /// exposed on the public surface.
    let signUpAutofillValues: [String: Any]?
    /// Attribute ids already auto-submitted from ``signUpAutofillValues`` during this sign-up flow.
    /// Used to detect when the server re-requests an attribute we already sent (e.g. after a
    /// validation failure) so the SDK surfaces an error to the app instead of resending in a loop.
    /// Carries no attribute values.
    let signUpAutofillSubmittedIds: Set<String>

    init(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        links: [String: URL],
        methodLinks: [String: URL] = [:],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        scopes: [String] = [],
        signUpAutofillValues: [String: Any]? = nil,
        signUpAutofillSubmittedIds: Set<String> = []
    ) {
        self.flowScenario = flowScenario
        self.continuationToken = continuationToken
        self.links = links
        self.methodLinks = methodLinks
        self.username = username
        self.sentToHint = sentToHint
        self.codeLength = codeLength
        self.authMethods = authMethods
        self.scopes = scopes
        self.signUpAutofillValues = signUpAutofillValues
        self.signUpAutofillSubmittedIds = signUpAutofillSubmittedIds
    }

    func link(_ relation: MSALNativeAuthV2LinkRelation) -> URL? {
        return links[relation.rawValue]
    }

    /// The challenge / enroll link associated with a specific auth method.
    func methodLink(for methodId: String) -> URL? {
        return methodLinks[methodId]
    }
}
