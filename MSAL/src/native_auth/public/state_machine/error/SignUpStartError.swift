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
public class SignUpStartError: MSALNativeAuthError {
    enum ErrorType: CaseIterable {
        case browserRequired
        case userAlreadyExists
        case invalidUsername
        case generalError
    }

    let type: ErrorType

    init(type: ErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }

    /// Describes why an error occurred and provides more information about the error.
    public override var errorDescription: String? {
        if let description = super.errorDescription {
            return description
        }

        switch type {
        case .browserRequired:
            return MSALNativeAuthErrorMessage.browserRequired
        case .userAlreadyExists:
            return MSALNativeAuthErrorMessage.userAlreadyExists
        case .invalidUsername:
            return MSALNativeAuthErrorMessage.invalidUsername
        case .generalError:
            return MSALNativeAuthErrorMessage.generalError
        }
    }

    /// Returns `true` if a browser is required to continue the operation.
    public var isBrowserRequired: Bool {
        return type == .browserRequired
    }

    /// Returns `true` when the user is trying to register an existing username.
    public var isUserAlreadyExists: Bool {
        return type == .userAlreadyExists
    }

    /// Returns `true` when the username is not valid.
    public var isInvalidUsername: Bool {
        return type == .invalidUsername
    }
}
