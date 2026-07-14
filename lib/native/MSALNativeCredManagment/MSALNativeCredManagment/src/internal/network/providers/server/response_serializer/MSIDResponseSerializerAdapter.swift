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

/// Adapter that bridges the pure-Swift `CredentialManagementHALResponseSerializer`
/// to IdentityCore's `MSIDResponseSerialization` protocol.
///
/// This is installed on `MSIDHttpRequest.responseSerializer` to integrate with
/// the IdentityCore transport pipeline while keeping parsing logic in pure Swift.
internal final class MSIDResponseSerializerAdapter: NSObject, MSIDResponseSerialization
{
    private let halSerializer = CredentialManagementHALResponseSerializer()

    func responseObject(for httpResponse: HTTPURLResponse?, data: Data?, context: MSIDRequestContext?) throws -> Any
    {
        guard let response = halSerializer.serialize(httpResponse: httpResponse, data: data) else
        {
            throw NSError(
                domain: "CredentialManagementErrorDomain",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No HTTP response received."]
            )
        }

        // For error status codes, throw so the error handler takes over
        guard response.isSuccess else
        {
            var userInfo: [String: Any] = [
                "statusCode": response.statusCode,
                "responseHeaders": response.headers
            ]
            if let data = data
            {
                userInfo["responseData"] = data
            }
            throw NSError(
                domain: "CredentialManagementErrorDomain",
                code: response.statusCode,
                userInfo: userInfo
            )
        }

        return response
    }
}
