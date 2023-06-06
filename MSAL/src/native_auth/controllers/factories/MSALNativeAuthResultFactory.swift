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

protocol MSALNativeAuthResultBuildable {

    var config: MSALNativeAuthConfiguration {get}

    func makeNativeAuthResponse(
        stage: MSALNativeAuthResponse.Stage,
        credentialToken: String?,
        tokenResult: MSIDTokenResult
    ) -> MSALNativeAuthResponse

    func makeUserAccount(tokenResult: MSIDTokenResult) -> MSALNativeAuthUserAccount

    func makeMSIDConfiguration(scope: [String]) -> MSIDConfiguration
}

final class MSALNativeAuthResultFactory: MSALNativeAuthResultBuildable {

    let config: MSALNativeAuthConfiguration

    init(config: MSALNativeAuthConfiguration) {
        self.config = config
    }

    func makeNativeAuthResponse(
        stage: MSALNativeAuthResponse.Stage,
        credentialToken: String?,
        tokenResult: MSIDTokenResult
    ) -> MSALNativeAuthResponse {
        return .init(
            stage: stage,
            credentialToken: credentialToken,
            authentication: .init(
                accessToken: tokenResult.accessToken.accessToken,
                idToken: tokenResult.rawIdToken,
                scopes: tokenResult.accessToken.scopes.array as? [String] ?? [],
                expiresOn: tokenResult.accessToken.expiresOn,
                tenantId: config.authority.tenant.rawTenant
            )
        )
    }

    func makeUserAccount(tokenResult: MSIDTokenResult) -> MSALNativeAuthUserAccount {
        return .init(
            username: tokenResult.accessToken.accountIdentifier.displayableId,
            accessToken: tokenResult.accessToken.accessToken,
            rawIdToken: tokenResult.rawIdToken,
            scopes: tokenResult.accessToken.scopes.array as? [String] ?? [],
            expiresOn: tokenResult.accessToken.expiresOn
        )
    }

    func makeMSIDConfiguration(scope: [String]) -> MSIDConfiguration {
        return .init(
            authority: config.authority,
            redirectUri: nil,
            clientId: config.clientId,
            target: scope.joined(separator: " ")
        )
    }
}
