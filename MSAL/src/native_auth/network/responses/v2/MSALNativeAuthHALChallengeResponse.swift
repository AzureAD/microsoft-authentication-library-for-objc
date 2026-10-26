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

final class MSALNativeAuthHALChallengeResponse: MSALNativeAuthHALResponse {

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

    /// `_embedded.methods` entries.
    let methods: [EmbeddedMethod]
    let hint: String?
    /// `challengeContext.authenticationFactor` (e.g. "singleFactor", "multiFactor"), when present.
    let authenticationFactor: String?

    init(
        statusCode: Int,
        correlationId: UUID?,
        continuationToken: String?,
        links: [String: String],
        error: ServerError?,
        isWebFallbackRequired: Bool,
        methods: [EmbeddedMethod],
        hint: String?,
        authenticationFactor: String?
    ) {
        self.methods = methods
        self.hint = hint
        self.authenticationFactor = authenticationFactor
        super.init(
            statusCode: statusCode,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: links,
            error: error,
            isWebFallbackRequired: isWebFallbackRequired
        )
    }
}
