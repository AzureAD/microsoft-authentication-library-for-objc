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

/// Implements `MSIDHttpRequestErrorHandling` for credential management API errors.
///
/// Maps HTTP error status codes to `MSALNativeCredentialManagementError` instances
/// and invokes the completion block with the appropriate typed error.
internal final class CredentialManagementErrorHandler: NSObject, MSIDHttpRequestErrorHandling
{
    private let correlationId: UUID

    init(correlationId: UUID)
    {
        self.correlationId = correlationId
    }

    func handleError(
        _ error: Error?,
        httpResponse: HTTPURLResponse?,
        data: Data?,
        httpRequest: MSIDHttpRequestProtocol?,
        responseSerializer: MSIDResponseSerialization?,
        externalSSOContext ssoContext: MSIDExternalSSOContext?,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    )
    {
        let statusCode = httpResponse?.statusCode ?? 0

        // MSIDHttpRequest only routes HTTP 200 through the response serializer; every other
        // status code (including successful 202 Accepted and 204 No Content) is delivered to
        // the error handler. Treat any 2xx as success and run the response serializer so the
        // caller receives the parsed response instead of a spurious error.
        if (200...299).contains(statusCode)
        {
            do
            {
                let responseObject = try responseSerializer?.responseObject(for: httpResponse, data: data, context: context)
                completionBlock?(responseObject, nil)
            }
            catch let serializerError
            {
                completionBlock?(nil, serializerError)
            }
            return
        }

        let mappedError: MSALNativeCredentialManagementError

        switch statusCode
        {
        case 401:
            mappedError = MSALNativeCredentialManagementError(
                type: .unauthorized,
                message: "Server returned 401 Unauthorized. The access token may be expired or invalid.",
                correlationId: correlationId
            )

        case 403:
            mappedError = MSALNativeCredentialManagementError(
                type: .forbidden,
                message: "Server returned 403 Forbidden. The user may lack the required permissions or recent MFA.",
                correlationId: correlationId
            )

        case 404:
            mappedError = MSALNativeCredentialManagementError(
                type: .notFound,
                message: "Server returned 404 Not Found. The credential method does not exist.",
                correlationId: correlationId
            )

        case 409:
            mappedError = MSALNativeCredentialManagementError(
                type: .conflict,
                message: "Server returned 409 Conflict. The credential method may already be registered.",
                correlationId: correlationId
            )

        case 429:
            mappedError = MSALNativeCredentialManagementError(
                type: .networkError,
                message: "Server returned 429 Too Many Requests. Please try again later.",
                correlationId: correlationId
            )

        default:
            if let error = error
            {
                mappedError = MSALNativeCredentialManagementError(
                    type: .networkError,
                    message: "Network request failed.",
                    correlationId: correlationId,
                    underlyingError: error
                )
            }
            else
            {
                let message: String
                if (500...599).contains(statusCode)
                {
                    message = "Server returned \(statusCode). A server-side error occurred."
                }
                else
                {
                    message = "Server returned unexpected status code \(statusCode)."
                }
                mappedError = MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: message,
                    correlationId: correlationId
                )
            }
        }

        completionBlock?(nil, mappedError)
    }
}
