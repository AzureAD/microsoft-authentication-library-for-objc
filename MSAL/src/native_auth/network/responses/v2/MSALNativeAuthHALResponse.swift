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

@_implementationOnly import MSAL_Private

/// Base type for a server-driven HAL response used by the Native Auth V2 flows.
class MSALNativeAuthHALResponse: MSALNativeAuthResponseCorrelatable {

    /// A server error body (`{ "error": { ... } }`).
    struct ServerError {
        let code: String?
        let message: String?
        let innerErrorCode: String?
        let correlationId: UUID?
    }

    let statusCode: Int
    var correlationId: UUID?

    let continuationToken: String?

    let links: [String: String]

    let error: ServerError?

    let isWebFallbackRequired: Bool

    init(
        statusCode: Int,
        correlationId: UUID?,
        continuationToken: String?,
        links: [String: String],
        error: ServerError?,
        isWebFallbackRequired: Bool
    ) {
        self.statusCode = statusCode
        self.correlationId = correlationId
        self.continuationToken = continuationToken
        self.links = links
        self.error = error
        self.isWebFallbackRequired = isWebFallbackRequired
    }

    func href(forRelation relation: String) -> String? {
        return links[relation]
    }

    func href(for relation: MSALNativeAuthV2LinkRelation) -> String? {
        return links[relation.rawValue]
    }
}
