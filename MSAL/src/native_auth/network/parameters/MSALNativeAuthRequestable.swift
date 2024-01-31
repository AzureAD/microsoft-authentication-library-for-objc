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

protocol MSALNativeAuthRequestable {
    var endpoint: MSALNativeAuthEndpoint { get }
    var context: MSALNativeAuthRequestContext { get }

    func makeEndpointUrl(config: MSALNativeAuthConfiguration) throws -> URL
    func makeRequestBody(config: MSALNativeAuthConfiguration) -> [String: String]
}

extension MSALNativeAuthRequestable {

    func makeEndpointUrl(config: MSALNativeAuthConfiguration) throws -> URL {
        var components = URLComponents(url: config.authority.url, resolvingAgainstBaseURL: true)
        components?.path += endpoint.rawValue

        if let dataCenter = config.sliceConfig?.dc {
            components?.queryItems = [URLQueryItem(name: "dc", value: dataCenter)]
        }

        guard let url = components?.url else {
            throw MSALNativeAuthInternalError.invalidUrl
        }

        return url
    }
}
