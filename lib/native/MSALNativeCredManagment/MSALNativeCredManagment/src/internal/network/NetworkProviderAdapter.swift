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

/// Adapts a public `MSALNativeCredentialManagementNetworkProvider` to the internal
/// `CredentialManagementNetworkClient` protocol.
///
/// This enables injection of custom/mock network providers via configuration
/// while keeping the internal transport protocol private.
internal final class NetworkProviderAdapter: CredentialManagementNetworkClient
{
    private let provider: MSALNativeCredentialManagementNetworkProvider

    init(provider: MSALNativeCredentialManagementNetworkProvider)
    {
        self.provider = provider
    }

    func perform(request: CredentialManagementRequest) async throws -> CredentialManagementResponse
    {
        let publicRequest = MSALCredentialManagementHTTPRequest(
            url: request.url,
            method: request.method.rawValue,
            headers: request.headers,
            body: request.body
        )

        let publicResponse = try await provider.performRequest(publicRequest)

        return CredentialManagementResponse(
            statusCode: publicResponse.statusCode,
            headers: publicResponse.headers,
            data: publicResponse.data
        )
    }
}
