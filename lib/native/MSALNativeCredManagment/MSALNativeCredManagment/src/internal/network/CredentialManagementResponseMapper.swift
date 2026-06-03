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

/// Maps HTTP response status codes to `MSALNativeCredentialManagementError`.
///
/// Handles success codes (200, 201, 204) and maps error codes to
/// appropriate `MSALNativeCredentialManagementErrorType` values.
internal struct CredentialManagementResponseMapper
{
    /// Validates that the response indicates success, or maps to a typed error.
    ///
    /// - Parameters:
    ///   - response: The HTTP response.
    ///   - correlationId: The request correlation ID for diagnostics.
    /// - Returns: nil if the response indicates success, or an error describing the failure.
    static func mapError(
        from response: CredentialManagementResponse,
        correlationId: UUID
    ) -> MSALNativeCredentialManagementError?
    {
        switch response.statusCode
        {
        case 200, 201, 204:
            return nil

        case 401:
            return MSALNativeCredentialManagementError(
                type: .unauthorized,
                message: "Server returned 401 Unauthorized. The access token may be expired or invalid.",
                correlationId: correlationId
            )

        case 403:
            return MSALNativeCredentialManagementError(
                type: .forbidden,
                message: "Server returned 403 Forbidden. The user may lack the required permissions or recent MFA.",
                correlationId: correlationId
            )

        case 404:
            return MSALNativeCredentialManagementError(
                type: .notFound,
                message: "Server returned 404 Not Found. The credential method does not exist.",
                correlationId: correlationId
            )

        case 409:
            return MSALNativeCredentialManagementError(
                type: .conflict,
                message: "Server returned 409 Conflict. The credential method may already be registered.",
                correlationId: correlationId
            )

        case 429:
            return MSALNativeCredentialManagementError(
                type: .networkError,
                message: "Server returned 429 Too Many Requests. Please try again later.",
                correlationId: correlationId
            )

        default:
            let message: String
            if (500...599).contains(response.statusCode)
            {
                message = "Server returned \(response.statusCode). A server-side error occurred."
            }
            else
            {
                message = "Server returned unexpected status code \(response.statusCode)."
            }
            return MSALNativeCredentialManagementError(
                type: .generalError,
                message: message,
                correlationId: correlationId
            )
        }
    }

    /// Decodes JSON body from a successful response.
    ///
    /// - Parameters:
    ///   - response: The HTTP response with body data.
    ///   - correlationId: The request correlation ID.
    /// - Returns: Decoded dictionary or an error.
    static func decodeJSON(
        from response: CredentialManagementResponse,
        correlationId: UUID
    ) -> Result<[String: Any], MSALNativeCredentialManagementError>
    {
        guard let data = response.data, !data.isEmpty else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Response body is empty.",
                correlationId: correlationId
            ))
        }

        do
        {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else
            {
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Response body is not a valid JSON object.",
                    correlationId: correlationId
                ))
            }
            return .success(json)
        }
        catch
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Failed to parse response JSON.",
                correlationId: correlationId,
                underlyingError: error
            ))
        }
    }
}
