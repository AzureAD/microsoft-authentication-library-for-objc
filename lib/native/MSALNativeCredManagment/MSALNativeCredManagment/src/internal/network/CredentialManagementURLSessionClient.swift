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
import MSAL

/// Concrete implementation of `CredentialManagementNetworkClient` using `URLSession`.
///
/// Modeled after `MSIDHttpRequest` patterns from IdentityCore:
/// - Configurable retry logic (`retryCount`, `retryInterval`)
/// - Configurable request timeout
/// - Request interceptor support for header injection (shared with MSAL)
/// - Retry on transient failures (5xx, timeout, network errors)
internal final class CredentialManagementURLSessionClient: CredentialManagementNetworkClient
{
    // MARK: - Configuration (mirrors MSIDHttpRequest properties)

    /// Number of retry attempts for transient failures. Default is 1.
    var retryCount: Int = 1

    /// Interval between retry attempts in seconds. Default is 0.5.
    var retryInterval: TimeInterval = 0.5

    /// Request timeout in seconds. Default is 30.
    var requestTimeoutInterval: TimeInterval = 30

    /// Optional request interceptor shared with MSAL for injecting custom headers.
    var requestInterceptor: MSALNativeAuthRequestInterceptor?

    // MARK: - Private

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared)
    {
        self.urlSession = urlSession
    }

    convenience init(
        requestInterceptor: MSALNativeAuthRequestInterceptor?,
        retryCount: Int = 1,
        retryInterval: TimeInterval = 0.5,
        requestTimeoutInterval: TimeInterval = 30
    )
    {
        self.init(urlSession: .shared)
        self.requestInterceptor = requestInterceptor
        self.retryCount = retryCount
        self.retryInterval = retryInterval
        self.requestTimeoutInterval = requestTimeoutInterval
    }

    // MARK: - CredentialManagementNetworkClient

    func perform(request: CredentialManagementRequest) async throws -> CredentialManagementResponse
    {
        var urlRequest = try await buildURLRequest(from: request)
        urlRequest.timeoutInterval = requestTimeoutInterval

        var lastError: Error?
        let maxAttempts = 1 + retryCount

        for attempt in 0..<maxAttempts
        {
            if attempt > 0
            {
                CredentialManagementLogger.log(
                    level: .info,
                    message: "Retrying request (attempt \(attempt + 1)/\(maxAttempts)) after \(retryInterval)s"
                )
                try await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
            }

            do
            {
                let (data, response) = try await urlSession.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else
                {
                    throw URLError(.badServerResponse)
                }

                let responseHeaders = httpResponse.allHeaderFields.reduce(into: [String: String]())
                { result, pair in
                    if let key = pair.key as? String, let value = pair.value as? String
                    {
                        result[key] = value
                    }
                }

                let credResponse = CredentialManagementResponse(
                    statusCode: httpResponse.statusCode,
                    headers: responseHeaders,
                    data: data
                )

                // Retry on transient server errors (5xx)
                if isRetryableStatusCode(httpResponse.statusCode) && attempt < maxAttempts - 1
                {
                    lastError = URLError(.badServerResponse)
                    continue
                }

                return credResponse
            }
            catch
            {
                lastError = error

                // Only retry on transient/network errors
                if !isRetryableError(error) || attempt >= maxAttempts - 1
                {
                    throw error
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Private Helpers

    private func buildURLRequest(from request: CredentialManagementRequest) async throws -> URLRequest
    {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        for (key, value) in request.headers
        {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Apply interceptor headers (mirrors MSIDHttpRequest's requestInterceptor pattern)
        if let interceptor = requestInterceptor
        {
            let additionalHeaders = await withCheckedContinuation
            { continuation in
                interceptor.addAdditionalHeaderFields(request.url)
                { headers in
                    continuation.resume(returning: headers ?? [:])
                }
            }

            for (key, value) in additionalHeaders
            {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        return urlRequest
    }

    private func isRetryableStatusCode(_ statusCode: Int) -> Bool
    {
        return (500...599).contains(statusCode) || statusCode == 429
    }

    private func isRetryableError(_ error: Error) -> Bool
    {
        let nsError = error as NSError
        let retryableCodes: [Int] = [
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet
        ]
        return nsError.domain == NSURLErrorDomain && retryableCodes.contains(nsError.code)
    }
}
