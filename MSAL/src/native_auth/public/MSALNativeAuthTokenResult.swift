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

public class MSALNativeAuthTokenResult: NSObject {

    let authTokens: MSALNativeAuthTokens

    init(authTokens: MSALNativeAuthTokens) {
        self.authTokens = authTokens
    }

    /**
     The Access Token requested.
     Note that if access token is not returned in token response, this property will be returned as an empty string.
     */
    @objc public var accessToken: String {
        authTokens.accessToken.accessToken
    }

    /// Get the list of permissions for the access token for the account.
    @objc public var scopes: [String] {
        authTokens.accessToken.scopes.array as? [String] ?? []
    }

    /// Get the expiration date for the access token for the account.
    /// This value is calculated based on current UTC time measured locally and the value expiresIn returned from the service
    @objc public var expiresOn: Date? {
        authTokens.accessToken.expiresOn
    }
}
