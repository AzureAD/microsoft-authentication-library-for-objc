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

struct MSALNativeAuthTokenRequestParameters: MSALNativeAuthRequestable {
    let endpoint: MSALNativeAuthEndpoint = .token
    let context: MSALNativeAuthRequestContext
    let username: String?
    let continuationToken: String?
    let grantType: MSALNativeAuthGrantType
    let scope: String?
    let password: String?
    let oobCode: String?
    let includeChallengeType: Bool
    let clientInfo = true
    let refreshToken: String?
    let claimsRequestJson: String?

    func makeRequestBody(config: MSALNativeAuthInternalConfiguration) -> [String: String] {
        typealias Key = MSALNativeAuthRequestParametersKey
        var parameters = [
            Key.clientId.rawValue: config.clientId,
            Key.username.rawValue: username,
            Key.continuationToken.rawValue: continuationToken,
            Key.grantType.rawValue: grantType.rawValue,
            Key.scope.rawValue: scope,
            Key.password.rawValue: password,
            Key.oobCode.rawValue: oobCode,
            Key.clientInfo.rawValue: clientInfo.description,
            Key.refreshToken.rawValue: refreshToken,
            Key.claims.rawValue: claimsRequestJson
        ]

        if includeChallengeType {
            parameters[Key.challengeType.rawValue] = config.challengeTypesString
        }

        return parameters.compactMapValues { $0 }
    }
}
