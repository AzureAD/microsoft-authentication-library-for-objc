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

/// A HAL follow-up request driven by a server-provided `href` (challenge, verify, submit*, register,
/// update-password, poll). JSON encoded with a typed ``MSALNativeAuthV2RequestBody``.
struct MSALNativeAuthV2HrefParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let href: String
    let httpMethod: String
    let apiId: MSALNativeAuthTelemetryApiId
    let operationType: MSALNativeAuthOperationType
    let requestBody: MSALNativeAuthV2RequestBody
    let encoding: MSALNativeAuthUrlRequestEncoding = .json

    var body: [AnyHashable: Any] {
        return requestBody.dictionary
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(forHref: href)
    }
}
