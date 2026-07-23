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
/// Holds the opaque server `continuation_token` and the resolved `_links` hrefs
/// the SDK must follow to advance the server-driven flow.
struct MSALNativeAuthFlowContinuationState {
    let flowScenario: MSALNativeAuthFlowScenario
    let continuationToken: String
    let links: [MSALNativeAuthV2LinkKey: URL]
    let username: String?
    let sentToHint: String?
    let codeLength: Int?
    /// Scopes (caller-requested merged with the default OIDC scopes) to request on the final
    /// `/token` exchange. Threaded through every step.
    let scopes: [String]

    init(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        links: [MSALNativeAuthV2LinkKey: URL],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        scopes: [String] = []
    ) {
        self.flowScenario = flowScenario
        self.continuationToken = continuationToken
        self.links = links
        self.username = username
        self.sentToHint = sentToHint
        self.codeLength = codeLength
        self.scopes = scopes
    }

    func link(_ relation: MSALNativeAuthV2LinkRelation) -> URL? {
        return links[.relation(relation)]
    }

    /// The challenge / enroll link associated with a specific auth method.
    func methodLink(for methodId: String) -> URL? {
        return links[.method(id: methodId)]
    }
}
