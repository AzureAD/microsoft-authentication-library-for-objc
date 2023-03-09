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

struct MSALNativeAuthSignUpRequestParameters: MSALNativeAuthRequestable {

    let authority: MSALNativeAuthAuthority
    let clientId: String
    let endpoint: MSALNativeAuthEndpoint
    let context: MSIDRequestContext
    let email: String
    let password: String?
    let attributes: String
    let scope: String
    let grantType: MSALNativeAuthGrantType
}

// MARK: - Convenience init

extension MSALNativeAuthSignUpRequestParameters {

    init(
        authority: MSALNativeAuthAuthority,
        clientId: String,
        email: String,
        password: String? = nil,
        attributes: String,
        scope: String,
        context: MSIDRequestContext,
        grantType: MSALNativeAuthGrantType
    ) {
        self.init(
            authority: authority,
            clientId: clientId,
            endpoint: .signUp,
            context: context,
            email: email,
            password: password,
            attributes: attributes,
            scope: scope,
            grantType: grantType
        )
    }
}
