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

import Foundation

@objcMembers
public class RetrieveAccessTokenError: MSALNativeAuthError {
    let type: RetrieveAccessTokenErrorType

    init(type: RetrieveAccessTokenErrorType, message: String? = nil) {
        self.type = type
        super.init(identifier: type.rawValue, message: message)
    }

    /// Describes an error that provides messages describing why an error occurred and provides more information about the error.
    public override var errorDescription: String? {
        return super.errorDescription ?? type.rawValue
    }

    /// Returns `true` if the error requires to use a browser.
    public var isBrowserRequired: Bool {
        return type == .browserRequired
    }

    /// Returns `true` if the refresh token has expired.
    public var isRefreshTokenExpired: Bool {
        return type == .refreshTokenExpired
    }

    /// Returns `true` if the existing token cannot be found.
    public var isTokenNotFound: Bool {
        return type == .tokenNotFound
    }
}

public enum RetrieveAccessTokenErrorType: String, CaseIterable {
    case browserRequired = "Browser required"
    case refreshTokenExpired = "Refresh token expired"
    case tokenNotFound = "Token not found"
    case generalError = "General error"
}
