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

@_implementationOnly import MSAL_Private

final class MSALNativeAuthResponseSerializer<T: Decodable & MSALNativeAuthResponseCorrelatable>: NSObject, MSIDResponseSerialization {

    func responseObject(for httpResponse: HTTPURLResponse?, data: Data?, context: MSIDRequestContext?) throws -> Any {
        guard let data = data else {
            MSALLogger.log(level: .error, context: context, format: "ResponseSerializer failed decoding. Empty Data")
            throw MSALNativeAuthInternalError.responseSerializationError(headerCorrelationId: T.retrieveCorrelationIdFromHeaders(from: httpResponse))
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            var response = try decoder.decode(T.self, from: data)
            response.correlationId = T.retrieveCorrelationIdFromHeaders(from: httpResponse)
            return response
        } catch {
            MSALLogger.log(level: .error, context: context, format: "ResponseSerializer failed decoding \(error)")
            throw MSALNativeAuthInternalError.responseSerializationError(headerCorrelationId: T.retrieveCorrelationIdFromHeaders(from: httpResponse))
        }
    }
}
