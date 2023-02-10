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

protocol MSALNativeAuthRequestProviding {
    func signInRequest(
        parameters: MSALNativeAuthSignInParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInRequest
}

final class MSALNativeAuthRequestProvider: MSALNativeAuthRequestProviding {

    // MARK: - Variables

    private let clientId: String
    private let authority: MSALNativeAuthAuthority
    private let telemetryProvider: MSALNativeAuthTelemetryProviding

    // MARK: - Init

    init(clientId: String, authority: MSALNativeAuthAuthority,
         telemetryProvider: MSALNativeAuthTelemetryProviding = MSALNativeAuthTelemetryProvider()) {
        self.clientId = clientId
        self.authority = authority
        self.telemetryProvider = telemetryProvider
    }

    // MARK: - SignIn with Password

    func signInRequest(
        parameters: MSALNativeAuthSignInParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInRequest {

        let params = MSALNativeAuthSignInRequestParameters(
            authority: authority,
            clientId: clientId,
            email: parameters.email,
            password: parameters.password,
            scope: parameters.scopes.joined(separator: ","),
            context: context
        )

        let request = try MSALNativeAuthSignInRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInWithPassword),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context),
            serverTelemetry: serverTelemetry
        )

        return request
    }
}
