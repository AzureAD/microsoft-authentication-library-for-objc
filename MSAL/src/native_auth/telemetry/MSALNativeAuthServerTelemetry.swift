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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
@_implementationOnly import MSAL_Private

class MSALNativeAuthServerTelemetry: NSObject, MSIDHttpRequestServerTelemetryHandling {

    let currentRequestTelemetry: MSALNativeAuthCurrentRequestTelemetry
    let context: MSIDRequestContext
    private let lastRequestTelemetry: MSIDLastRequestTelemetry
    init(currentRequestTelemetry: MSALNativeAuthCurrentRequestTelemetry,
         context: MSIDRequestContext) {
        self.currentRequestTelemetry = currentRequestTelemetry
        self.context = context
        self.lastRequestTelemetry = MSIDLastRequestTelemetry.sharedInstance()
    }

    func handleError(_ error: Error?, context: MSIDRequestContext) {
        guard let error = error else { return }
        let errorString = (error as NSError).msidServerTelemetryErrorString()
        handleError(error, errorString: errorString, context: context)
    }

    func handleError(_ error: Error?, errorString: String, context: MSIDRequestContext) {
        lastRequestTelemetry.update(withApiId: currentRequestTelemetry.apiId.rawValue,
                                    errorString: errorString,
                                    context: context)
    }

    func setTelemetryToRequest(_ request: MSIDHttpRequestProtocol) {

        let currentRequestTelemetryString = currentRequestTelemetry.telemetryString()
        let lastRequestTelemetryString = lastRequestTelemetry.telemetryString()

        guard let mutableUrlRequest = (request.urlRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Mutable copy of request could not be made for telemetry")
            return
        }
        mutableUrlRequest.setValue(currentRequestTelemetryString, forHTTPHeaderField: "x-client-current-telemetry")
        mutableUrlRequest.setValue(lastRequestTelemetryString, forHTTPHeaderField: "x-client-last-telemetry")
        request.urlRequest = mutableUrlRequest as URLRequest
    }
}
