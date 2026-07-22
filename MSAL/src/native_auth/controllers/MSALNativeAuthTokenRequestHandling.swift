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

@_implementationOnly import MSAL_Private

protocol MSALNativeAuthTokenRequestHandling {

    func performTokenRequest(
        _ request: MSIDHttpRequest,
        context: MSIDRequestContext
    ) async -> Result<MSALNativeAuthCIAMTokenResponse, Error>
}

extension MSALNativeAuthTokenRequestHandling {

    func performTokenRequest(
        _ request: MSIDHttpRequest,
        context: MSIDRequestContext
    ) async -> Result<MSALNativeAuthCIAMTokenResponse, Error> {
        let requestCorrelationId = request.context?.correlationId().uuidString
        return await withCheckedContinuation { continuation in
            request.send { response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                guard let responseDict = response as? [AnyHashable: Any] else {
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                    return
                }
                do {
                    let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: responseDict)
                    // use request correlation id if server doesn't return one
                    tokenResponse.correlationId = tokenResponse.correlationId ?? requestCorrelationId
                    continuation.resume(returning: .success(tokenResponse))
                } catch {
                    MSALNativeAuthLogger.log(level: .error, context: context, format: "Error token request - Both result and error are nil")
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                }
            }
        }
    }
}
