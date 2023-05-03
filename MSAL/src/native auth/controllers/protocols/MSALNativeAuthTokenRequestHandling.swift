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

protocol MSALNativeAuthTokenRequestHandling where Self: MSALNativeAuthBaseController {

    typealias TokenRequestCompletionHandler = (Result<MSIDAADTokenResponse, Error>) -> Void

    func performRequest(_ request: MSIDHttpRequest, completion: @escaping TokenRequestCompletionHandler)
    
    func cacheTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration)
}

extension MSALNativeAuthTokenRequestHandling {

    func performRequest(_ request: MSIDHttpRequest, completion: @escaping TokenRequestCompletionHandler) {
        request.send { response, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let responseDict = response as? [AnyHashable: Any] else {
                completion(.failure(MSALNativeAuthError.invalidResponse))
                return
            }

            do {
                let tokenResponse = try MSIDAADTokenResponse(jsonDictionary: responseDict)
                tokenResponse.correlationId = request.context?.correlationId().uuidString
                completion(.success(tokenResponse))
            } catch {
                completion(.failure(MSALNativeAuthError.invalidResponse))
            }
        }
    }

    func cacheTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration) {
        do {
            try cacheAccessor?.saveTokensAndAccount(
                tokenResult: tokenResponse,
                configuration: msidConfiguration,
                context: context
            )
        } catch {

            // Note, if there's an error saving result, we log it, but we don't return an error
            // This is by design because even if we fail to cache, we still should return tokens back to the app

            MSALLogger.log(
                level: .error,
                context: context,
                format: "Error caching response: \(error) (ignoring)"
            )
        }
    }
}
