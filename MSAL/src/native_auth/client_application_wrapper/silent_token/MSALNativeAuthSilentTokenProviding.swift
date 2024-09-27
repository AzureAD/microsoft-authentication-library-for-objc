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

class MSALNativeAuthSilentTokenResult {
    let accessTokenResult: MSALNativeAuthTokenResult
    let rawIdToken: String?
    let account: MSALAccount
    let correlationId: UUID

    init(result: MSALResult) {
        self.rawIdToken = result.idToken
        self.account = result.account
        self.accessTokenResult = MSALNativeAuthTokenResult(accessToken: result.accessToken,
                                                           scopes: result.scopes,
                                                           expiresOn: result.expiresOn)
        self.correlationId = result.correlationId
    }

    init (accessTokenResult: MSALNativeAuthTokenResult,
          rawIdToken: String?,
          account: MSALAccount,
          correlationId: UUID) {
        self.rawIdToken = rawIdToken
        self.account = account
        self.accessTokenResult = accessTokenResult
        self.correlationId = correlationId
    }
}

typealias MSALNativeAuthSilentTokenResponse = (MSALNativeAuthSilentTokenResult?, (any Error)?) -> Void

protocol MSALNativeAuthSilentTokenProviding {
    func acquireTokenSilent(parameters: MSALSilentTokenParameters, completionBlock: @escaping MSALNativeAuthSilentTokenResponse)
}
