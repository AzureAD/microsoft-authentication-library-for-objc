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

/// `POST /authorize/challenge` (the authorization challenge that starts a flow).
struct MSALNativeAuthV2AuthorizeChallengeStartParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let clientId: String
    let scopes: [String]?
    let claimsRequestJson: String?
    let apiId: MSALNativeAuthTelemetryApiId
    let encoding: MSALNativeAuthUrlRequestEncoding = .wwwFormUrlEncoded
    let operationType: MSALNativeAuthOperationType = MSALNativeAuthV2OperationType.authorizeChallengeStart.rawValue

    var body: [AnyHashable: Any] {
        var form: [AnyHashable: Any] = [MSALNativeAuthRequestParametersKey.clientId.rawValue: clientId]
        if let scopes = scopes, !scopes.isEmpty {
            form[MSALNativeAuthRequestParametersKey.scope.rawValue] = scopes.joined(separator: " ")
        }
        if let claimsRequestJson = claimsRequestJson {
            form[MSALNativeAuthRequestParametersKey.claims.rawValue] = claimsRequestJson
        }
        return form
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(for: .authorizeChallenge)
    }

    init(
        context: MSALNativeAuthRequestContext,
        clientId: String,
        scopes: [String]? = nil,
        claimsRequestJson: String? = nil,
        apiId: MSALNativeAuthTelemetryApiId
    ) {
        self.context = context
        self.clientId = clientId
        self.scopes = scopes
        self.claimsRequestJson = claimsRequestJson
        self.apiId = apiId
    }
}
