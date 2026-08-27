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

/// Typed key for a continuation state's link map: either a flow `_links` relation or a
/// per-auth-method action link (keyed by method id).
enum MSALNativeAuthV2LinkKey: Hashable {
    case relation(MSALNativeAuthV2LinkRelation)
    case method(id: String)
}

/// Internal continuation context carried by a ``MSALNativeAuthFlowInternalState``.
///
/// Holds the opaque server `continuation_token` and the resolved `_links` hrefs the SDK must
/// follow to advance the server-driven flow.
class MSALNativeAuthFlowContinuationState {
    let flowScenario: MSALNativeAuthFlowScenario
    let correlationId: UUID
    let continuationToken: String?
    let links: [MSALNativeAuthV2LinkKey: URL]
    let scopes: [String]
    let claimsRequestJson: String?
    /// Names of the attributes the SDK has already submitted to the server during sign up (including
    /// `email` and, when supplied, `password`). Used to detect when the server re-requests
    /// an attribute that was already submitted, which is treated as an unrecoverable error.
    let submittedAttributes: [String]

    init(
        flowScenario: MSALNativeAuthFlowScenario,
        correlationId: UUID,
        continuationToken: String?,
        links: [MSALNativeAuthV2LinkKey: URL],
        scopes: [String] = [],
        claimsRequestJson: String? = nil,
        submittedAttributes: [String] = []
    ) {
        self.flowScenario = flowScenario
        self.correlationId = correlationId
        self.continuationToken = continuationToken
        self.links = links
        self.scopes = scopes
        self.claimsRequestJson = claimsRequestJson
        self.submittedAttributes = submittedAttributes
    }

    func addingSubmittedAttributes(_ names: [String]) -> MSALNativeAuthFlowContinuationState {
        var merged = submittedAttributes
        for name in names where !merged.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            merged.append(name)
        }
        return MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: links,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            submittedAttributes: merged
        )
    }

    func link(_ relation: MSALNativeAuthV2LinkRelation) -> URL? {
        return links[.relation(relation)]
    }

    /// The challenge / enroll link associated with a specific auth method.
    func methodLink(for methodId: String) -> URL? {
        return links[.method(id: methodId)]
    }
}
