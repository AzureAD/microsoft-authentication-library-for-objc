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
public class ResetPasswordStartError: MSALNativeAuthError {
    let type: ResetPasswordStartErrorType

    init(type: ResetPasswordStartErrorType, message: String? = nil) {
        self.type = type
        super.init(identifier: type.rawValue, message: message)
    }

    /// Describes why an error occurred and provides more information about the error.
    public override var errorDescription: String? {
        if let description = super.errorDescription {
            return description
        }

        switch type {
        case .browserRequired:
            return MSALNativeAuthErrorMessage.browserRequired
        case .userDoesNotHavePassword:
            return MSALNativeAuthErrorMessage.userDoesNotHavePassword
        case .userNotFound:
            return MSALNativeAuthErrorMessage.userNotFound
        case .invalidUsername:
            return MSALNativeAuthErrorMessage.invalidUsername
        case .generalError:
            return MSALNativeAuthErrorMessage.generalError
        }
    }

    /// Returns `true` if the error requires to use a browser.
    public var isBrowserRequired: Bool {
        return type == .browserRequired
    }

    /// Returns `true` if the user does not have a password.
    public var isUserDoesNotHavePassword: Bool {
        return type == .userDoesNotHavePassword
    }

    /// Returns `true` if the user that is trying to reset their password cannot be found.
    public var isUserNotFound: Bool {
        return type == .userNotFound
    }

    /// Returns `true` when the username is not valid.
    public var isInvalidUsername: Bool {
        return type == .invalidUsername
    }
}

public enum ResetPasswordStartErrorType: String, CaseIterable {
    case browserRequired = "browser_required"
    case userDoesNotHavePassword = "user_does_not_have_password"
    case userNotFound = "user_not_found"
    case invalidUsername = "invalid_username"
    case generalError = "general_error"
}
