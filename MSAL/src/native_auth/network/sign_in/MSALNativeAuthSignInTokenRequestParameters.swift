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

struct MSALNativeAuthSignInTokenRequestParameters: MSALNativeAuthRequestable {

    let config: MSALNativeAuthConfiguration
    let endpoint: MSALNativeAuthEndpoint = .token
    let context: MSIDRequestContext
    let username: String?
    let credentialToken: String?
    let signInSLT: String?
    let grantType: MSALNativeAuthGrantType
    let scope: String?
    let password: String?
    let oobCode: String?
    let clientInfo = true

    func makeRequestBody() -> [String: String] {
        typealias Key = MSALNativeAuthRequestParametersKey
        var parameters = [
            Key.clientId.rawValue: config.clientId,
            Key.username.rawValue: username,
            Key.credentialToken.rawValue: credentialToken,
            Key.signInSLT.rawValue: signInSLT,
            Key.grantType.rawValue: grantType.rawValue,
            Key.scope.rawValue: scope,
            Key.password.rawValue: password,
            Key.oobCode.rawValue: oobCode
            // TODO: Do we send this parameter?
            // Key.clientInfo: clientInfo
        ]

        // For ROPC case and only for that the challenge type should be present
        if username != nil, password != nil {
            parameters[Key.challengeType.rawValue] = config.challengeTypesString
        }

        return parameters.compactMapValues { $0 }
    }
}
