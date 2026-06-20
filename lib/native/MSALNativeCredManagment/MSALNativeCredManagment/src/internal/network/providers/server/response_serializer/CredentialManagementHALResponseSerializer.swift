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

/// Concrete response serializer that parses raw HTTP into `CredentialManagementResponse`.
/// Handles HAL+JSON content by parsing the body as JSON.
internal final class CredentialManagementHALResponseSerializer: CredentialManagementResponseSerializing
{
    func serialize(httpResponse: HTTPURLResponse?, data: Data?) -> CredentialManagementResponse?
    {
        guard let httpResponse = httpResponse else
        {
            return nil
        }

        let statusCode = httpResponse.statusCode
        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]())
        { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String
            {
                result[key] = value
            }
        }

        // For 204 No Content or empty body, return response without JSON
        if statusCode == 204 || data == nil || data?.isEmpty == true
        {
            return CredentialManagementResponse(
                statusCode: statusCode,
                headers: headers,
                jsonBody: nil,
                rawData: data
            )
        }

        // Parse JSON body
        var jsonBody: [String: Any]?
        if let data = data
        {
            jsonBody = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }

        return CredentialManagementResponse(
            statusCode: statusCode,
            headers: headers,
            jsonBody: jsonBody,
            rawData: data
        )
    }
}
