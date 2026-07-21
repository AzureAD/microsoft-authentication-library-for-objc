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

@_implementationOnly import MSAL_Private

/// Generic, server-driven HAL response used by all Native Auth V2 flows.
///
/// Every V2 HTTP outcome (200 success, the `401` from `authorize-challenge`,
/// and `4xx` error bodies) is parsed into a single ``MSALNativeAuthHALResponse``. The
/// V2 response validator then inspects `error`, `state` and `action` to decide how the
/// flow should proceed. HAL parsing itself is delegated to the shared
/// `HALResource` / `HALLink` Swift types.
struct MSALNativeAuthHALResponse: MSALNativeAuthResponseCorrelatable {

    /// A method embedded in a HAL `_embedded.methods` array (e.g. an email OTP method).
    struct EmbeddedMethod: Equatable {
        let id: String?
        let type: String?
        let hint: String?
        /// `_links` of the embedded method, keyed by relation (e.g. "challenge", "verify"), value is the raw href.
        let links: [String: String]

        func link(for relation: MSALNativeAuthV2LinkRelation) -> String? {
            return links[relation.rawValue]
        }
    }

    /// An attribute the server requires during sign up (`collectAttributes` action).
    struct RequiredAttributeEntry: Equatable {
        let id: String?
        let type: String?
        let required: Bool
        let regex: String?
    }

    /// A server error body (`{ "error": { ... } }`).
    struct ServerError {
        let code: String?
        let message: String?
        let innerErrorCode: String?
        let correlationId: UUID?
    }

    let statusCode: Int
    var correlationId: UUID?

    let state: String?
    let action: String?
    let continuationToken: String?
    let codeLength: Int?
    let hint: String?

    /// The authentication factor required by a `challenge` action, taken from
    /// `challengeContext.authenticationFactor` (e.g. "multiFactor" when MFA is required).
    let authenticationFactor: String?

    /// Top-level method identifier (`id`) on method-style responses (sign up `start`, JIT `activate`).
    let methodId: String?
    /// Top-level method type (`type`, e.g. "email") on method-style responses.
    let methodType: String?
    /// Attributes the server requests on a sign up `collectAttributes` response.
    let attributes: [RequiredAttributeEntry]

    /// Authorization code from the final `authorize-challenge` call.
    let code: String?
    /// Access token from the `/token` exchange.
    let accessToken: String?

    /// Top-level `_links`, keyed by relation, value is the raw href string.
    let links: [String: String]
    /// `_embedded.methods` entries.
    let methods: [EmbeddedMethod]

    let error: ServerError?

    /// The typed `action` this response instructs the SDK to perform, or `nil` when absent/unknown.
    var halAction: MSALNativeAuthV2HALAction? {
        return action.flatMap(MSALNativeAuthV2HALAction.init(rawValue:))
    }

    var isReadyToComplete: Bool {
        return state == "continue"
    }

    func href(forRelation relation: String) -> String? {
        return links[relation]
    }

    func href(for relation: MSALNativeAuthV2LinkRelation) -> String? {
        return links[relation.rawValue]
    }
}
