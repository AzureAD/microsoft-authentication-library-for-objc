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

final class MSALNativeAuthRequestErrorHandler: NSObject, MSIDHttpRequestErrorHandling {

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
            if let completionBlock = completionBlock {
                completionBlock(nil, error)
            }
            return
        }

        if shouldRetry(httpResponse: httpResponse,
                       httpRequest: httpRequest,
                       context: context,
                       completionBlock: completionBlock) {
            return
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            // pkeyauth challenge
            if handleAuthenticateHeader(httpResponse: httpResponse,
                                        httpRequest: httpRequest,
                                        context: context,
                                        completionBlock: completionBlock) {
                return
            }

            handleAPIError(data: data, completionBlock: completionBlock)
            return
        }

        handleHTTPError(httpResponse: httpResponse,
                        context: context,
                        completionBlock: completionBlock)
    }

    func shouldRetry(httpResponse: HTTPURLResponse,
                     httpRequest: MSIDHttpRequestProtocol?,
                     context: MSIDRequestContext?,
                     completionBlock: MSIDHttpRequestDidCompleteBlock?) -> Bool {
        var shouldRetry = true
        shouldRetry = (httpRequest?.retryCounter ?? 0) > 0
        // 5xx Server errors.
        shouldRetry = shouldRetry && httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599
        if shouldRetry {
            httpRequest?.retryCounter -= 1
            if let context = context {
                MSALLogger.log(level: .verbose,
                               context: context,
                               format: "Retrying network request, retryCounter: %d", httpRequest?.retryCounter ?? 0)
            }

            let deadline = DispatchTime.now() + Double(UInt64(httpRequest?.retryInterval ?? 0) * NSEC_PER_SEC )
            DispatchQueue.main.asyncAfter(deadline: deadline) {
                httpRequest?.send(completionBlock)
            }

            return true
        }
        return false
    }

    func handleAuthenticateHeader(
        httpResponse: HTTPURLResponse,
        httpRequest: MSIDHttpRequestProtocol?,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) -> Bool {
        let wwwAuthValue = httpResponse.allHeaderFields[kMSIDWwwAuthenticateHeader] as? String
        if !NSString.msidIsStringNilOrBlank(wwwAuthValue),
           let wwwAuthValue = wwwAuthValue,
           wwwAuthValue.contains(kMSIDPKeyAuthName) {

            MSIDPKeyAuthHandler.handleWwwAuthenticateHeader(wwwAuthValue,
                                                            request: httpRequest?.urlRequest.url,
                                                            context: context) { authHeader, completionError in
                if !NSString.msidIsStringNilOrBlank(authHeader) {
                    // append auth header
                    if let newRequest = (httpRequest?.urlRequest as? NSURLRequest)?
                        .mutableCopy() as? NSMutableURLRequest {
                        newRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
                        httpRequest?.urlRequest = newRequest as URLRequest

                        DispatchQueue.main.async {
                            httpRequest?.send(completionBlock)
                        }
                    }
                    return
                }
                if let completionBlock = completionBlock {
                    completionBlock(nil, completionError)
                }
            }
            return true
        }
        return false
    }

    func handleAPIError(
        data: Data?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        do {
            let errorObject = try JSONDecoder()
                .decode(MSALNativeAuthErrorRequestResponse.self, from: data ?? Data())
            if let completionBlock = completionBlock {
                let innerError = MSALNativeAuthRequestError(error: errorObject.error,
                                                            errorDescription: errorObject.errorDescription,
                                                            errorURI: errorObject.errorURI,
                                                            innerErrors: errorObject.innerErrors)
                completionBlock(nil, innerError)
            }
        } catch {
            if let completionBlock = completionBlock {
                completionBlock(nil, error)
            }
        }
    }

    func handleHTTPError(
        httpResponse: HTTPURLResponse,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        let statusCode = httpResponse.statusCode
        let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        if let context = context {
            MSALLogger.log(level: .warning,
                           context: context,
                           format: "Http error raised. Http Code: %d Description %@", statusCode,
                           MSALLogMask.maskPII(errorDescription))
        }

        var additionalInfo = [AnyHashable: Any]()
        additionalInfo[MSIDHTTPHeadersKey] = httpResponse.allHeaderFields
        additionalInfo[MSIDHTTPResponseCodeKey] = String(httpResponse.statusCode)

        if statusCode >= 500, statusCode <= 599 {
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
            if let completionBlock = completionBlock {
                completionBlock(nil, httpError)
            }
        }
    }
}
