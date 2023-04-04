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

// swiftlint:disable:next type_name
struct MSALNativeAuthSignInTokenRequestParameters: MSALNativeAuthRequestable {

    let config: MSALNativeAuthConfiguration
    let endpoint: MSALNativeAuthEndpoint
    let context: MSIDRequestContext
    let username: String?
    let credentialToken: String?
    let signInSLT: String?
    let grantType: MSALNativeAuthGrantType
    let challengeType: MSALNativeAuthChallengeType?
    let scope: String?
    let password: String?
    let oob: String?
}

// MARK: - Convenience init

extension MSALNativeAuthSignInTokenRequestParameters {

    init(
        config: MSALNativeAuthConfiguration,
        context: MSIDRequestContext,
        username: String? = nil,
        credentialToken: String? = nil,
        signInSLT: String? = nil,
        grantType: MSALNativeAuthGrantType,
        challengeType: MSALNativeAuthChallengeType? = nil,
        scope: String? = nil,
        password: String? = nil,
        oob: String? = nil
    ) {
        self.init(
            config: config,
            endpoint: .token,
            context: context,
            username: username,
            credentialToken: credentialToken,
            signInSLT: signInSLT,
            grantType: grantType,
            challengeType: challengeType,
            scope: scope,
            password: password,
            oob: oob
        )
    }
}
