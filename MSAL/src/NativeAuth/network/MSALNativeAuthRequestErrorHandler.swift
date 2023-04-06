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

final class MSALNativeAuthRequestErrorHandler<T: Decodable & Error>: NSObject, MSIDHttpRequestErrorHandling {
    private var customError: T?

    // swiftlint:disable:next function_parameter_count
    func handleError(
        _ error: Error?,
        httpResponse: HTTPURLResponse?,
        data: Data?,
        httpRequest: MSIDHttpRequestProtocol?,
        responseSerializer: MSIDResponseSerialization?,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        guard let httpResponse = httpResponse else {
            completionBlock?(nil, error)
            return
        }

        if shouldRetry(httpResponse: httpResponse, httpRequest: httpRequest) {
            retryRequest(httpRequest: httpRequest,
                         context: context,
                         completionBlock: completionBlock)
            return
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            // PKeyAuth challenge
            if let authValue = wwwAuthValue(httpResponse: httpResponse) {
                handleAuthenticateHeader(wwwAuthValue: authValue,
                                         httpRequest: httpRequest,
                                         context: context,
                                         completionBlock: completionBlock)
                return
            }

            handleAPIError(data: data, completionBlock: completionBlock)
            return
        }

        handleHTTPError(httpResponse: httpResponse,
                        context: context,
                        completionBlock: completionBlock)
    }

    private func shouldRetry(httpResponse: HTTPURLResponse,
                             httpRequest: MSIDHttpRequestProtocol?) -> Bool {
        guard let httpRequest = httpRequest, httpRequest.retryCounter > 0 else {
            return false
        }
        return httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599
    }

    private func retryRequest(
        httpRequest: MSIDHttpRequestProtocol?,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        httpRequest?.retryCounter -= 1
        if let context = context {
            MSALLogger.log(level: .verbose,
                           context: context,
                           format: "Retrying network request, retryCounter: %d", httpRequest?.retryCounter ?? 0)
        }
        let deadline = DispatchTime.now() + Double(UInt64(httpRequest?.retryInterval ?? 0) * NSEC_PER_SEC )
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            httpRequest?.send(completionBlock)
        }
    }

    private func wwwAuthValue(httpResponse: HTTPURLResponse) -> String? {
        let wwwAuthKey = httpResponse.allHeaderFields.keys.first(where: {
            if let keyNameUppercased = ($0 as? String)?.uppercased() {
                return keyNameUppercased == kMSIDWwwAuthenticateHeader.uppercased()
            }
            return false
        })
        let wwwAuthValue = httpResponse
                            .allHeaderFields[wwwAuthKey ?? "" as Dictionary<AnyHashable, Any>.Keys.Element] as? String

        if !NSString.msidIsStringNilOrBlank(wwwAuthValue),
            let wwwAuthValue = wwwAuthValue,
            wwwAuthValue.contains(kMSIDPKeyAuthName) {
            return wwwAuthValue
        }
        return nil
    }

    private func handleAuthenticateHeader(
        wwwAuthValue: String,
        httpRequest: MSIDHttpRequestProtocol?,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        MSIDPKeyAuthHandler.handleWwwAuthenticateHeader(wwwAuthValue,
                                                        request: httpRequest?.urlRequest.url,
                                                        context: context) { authHeader, completionError in
            if !NSString.msidIsStringNilOrBlank(authHeader) {
                // Append Auth Header
                if var newRequest = httpRequest?.urlRequest {
                    newRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
                    httpRequest?.urlRequest = newRequest as URLRequest

                    DispatchQueue.global().async {
                        httpRequest?.send(completionBlock)
                    }
                }
                return
            }
            completionBlock?(nil, completionError)
        }
    }

    private func handleAPIError(
        data: Data?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        do {
            customError = try JSONDecoder().decode(T.self, from: data ?? Data())
            completionBlock?(nil, customError)
        } catch {
            completionBlock?(nil, error)
        }
    }

    private func handleHTTPError(
        httpResponse: HTTPURLResponse,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        let statusCode = httpResponse.statusCode
        let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        if let context = context {
            MSALLogger.log(level: .warning,
                           context: context,
                           format: "HTTP error raised. HTTP Code: %d Description %@", statusCode,
                           MSALLogMask.maskPII(errorDescription))
        }

        var additionalInfo = [AnyHashable: Any]()
        additionalInfo[MSIDHTTPHeadersKey] = httpResponse.allHeaderFields
        additionalInfo[MSIDHTTPResponseCodeKey] = String(httpResponse.statusCode)

        if statusCode >= 500 && statusCode <= 599 {
            additionalInfo[MSIDServerUnavailableStatusKey] = NSNumber(value: 1)
        }

        if let context = context {
            let httpError  = MSIDCreateError(MSIDHttpErrorCodeDomain,
                                             MSIDErrorCode.serverUnhandledResponse.rawValue,
                                             errorDescription,
                                             nil,
                                             nil,
                                             nil,
                                             context.correlationId(),
                                             additionalInfo,
                                             true)
            completionBlock?(nil, httpError)
        }
    }
}
