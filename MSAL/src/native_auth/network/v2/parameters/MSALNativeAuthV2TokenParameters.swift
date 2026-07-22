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

/// `POST /token` authorization-code exchange. Form encoded, raw OAuth (non-HAL) response. 
struct MSALNativeAuthV2TokenParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let clientId: String
    let code: String
    let scopes: [String]
    let encoding: MSALNativeAuthUrlRequestEncoding = .wwwFormUrlEncoded
    let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2Token
    let operationType: MSALNativeAuthOperationType = MSALNativeAuthV2OperationType.token.rawValue
    let expectsRawJSONResponse = true

    var body: [AnyHashable: Any] {
        var form: [AnyHashable: Any] = [
            MSALNativeAuthRequestParametersKey.grantType.rawValue: "authorization_code",
            MSALNativeAuthV2RequestBodyKey.code.rawValue: code,
            MSALNativeAuthRequestParametersKey.clientId.rawValue: clientId,
            MSALNativeAuthRequestParametersKey.clientInfo.rawValue: true.description
        ]
        if !scopes.isEmpty {
            form[MSALNativeAuthRequestParametersKey.scope.rawValue] = scopes.joined(separator: " ")
        }
        return form
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(for: .token)
    }
}
