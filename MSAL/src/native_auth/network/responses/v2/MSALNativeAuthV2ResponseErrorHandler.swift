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

/// Error handler for the Native Auth V2 transport pipeline.
///
/// `MSIDHttpRequest` only routes HTTP 200 through the response serializer; every other
/// status code is delivered here. In V2 the meaningful body lives on every outcome —
/// the `401` from `authorize-challenge` carries the `continuation_token`, and
/// `4xx` responses carry an `error` object. So this handler simply re-runs the HAL
/// response serializer for any status and hands the parsed ``MSALNativeAuthHALResponse``
/// back to the caller; the V2 validator (not the transport) decides success vs failure.
final class MSALNativeAuthV2ResponseErrorHandler: NSObject, MSIDHttpRequestErrorHandling {

    // swiftlint:disable:next function_parameter_count
    func handleError(
        _ error: Error?,
        httpResponse: HTTPURLResponse?,
        data: Data?,
        httpRequest: MSIDHttpRequestProtocol?,
        responseSerializer: MSIDResponseSerialization?,
        externalSSOContext ssoContext: MSIDExternalSSOContext?,
        context: MSIDRequestContext?,
        completionBlock: MSIDHttpRequestDidCompleteBlock?
    ) {
        let serializer = responseSerializer ?? MSALNativeAuthV2HALResponseSerializer()

        do {
            let responseObject = try serializer.responseObject(for: httpResponse, data: data, context: context)
            completionBlock?(responseObject, nil)
        } catch let serializerError {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "V2 error handler could not parse response body")
            completionBlock?(nil, serializerError)
        }
    }
}
