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

enum MSALNativeAuthSignUpContinueOauth2ErrorCode: String, Decodable, CaseIterable {
    case invalidRequest = "invalid_request"
    case invalidClient = "invalid_client"
    case invalidGrant = "invalid_grant"
    case expiredToken = "expired_token"
    case passwordTooWeak = "password_too_weak"
    case passwordTooShort = "password_too_short"
    case passwordTooLong = "password_too_long"
    case passwordRecentlyUsed = "password_recently_used"
    case passwordBanned = "password_banned"
    case userAlreadyExists = "user_already_exists"
    case attributesRequired = "attributes_required"
    case verificationRequired = "verification_required"
    case attributeValidationFailed = "attribute_validation_failed"
    case credentialRequired = "credential_required"
    case invalidOOBValue = "invalid_oob_value"
}

extension MSALNativeAuthSignUpContinueOauth2ErrorCode {

    func toVerifyCodePublicError() -> VerifyCodeError {
        switch self {
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .invalidOOBValue:
            return .init(type: .invalidCode)
        case .expiredToken:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.expiredToken)
        case .invalidRequest,
             .invalidGrant,
             .passwordTooWeak,
             .passwordTooShort,
             .passwordTooLong,
             .passwordRecentlyUsed,
             .passwordBanned,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired,
             .attributeValidationFailed:
            return .init(type: .generalError)
        }
    }

    func toPasswordRequiredPublicError() -> PasswordRequiredError {
        switch self {
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .expiredToken:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.expiredToken)
        case .passwordTooWeak:
            return .init(type: .invalidPassword, message: MSALNativeAuthErrorMessage.passwordTooWeak)
        case .passwordTooShort:
            return .init(type: .invalidPassword, message: MSALNativeAuthErrorMessage.passwordTooShort)
        case .passwordTooLong:
            return .init(type: .invalidPassword, message: MSALNativeAuthErrorMessage.passwordTooLong)
        case .passwordRecentlyUsed:
            return .init(type: .invalidPassword, message: MSALNativeAuthErrorMessage.passwordRecentlyUsed)
        case .passwordBanned:
            return .init(type: .invalidPassword, message: MSALNativeAuthErrorMessage.passwordBanned)
        case .invalidRequest,
             .invalidGrant,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired,
             .attributeValidationFailed,
             .invalidOOBValue:
            return .init(type: .generalError)
        }
    }

    func toAttributesRequiredPublicError() -> AttributesRequiredError {
        switch self {
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .attributeValidationFailed:
            return .init(type: .invalidAttributes)
        case .expiredToken:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.expiredToken)
        case .invalidRequest,
             .invalidGrant,
             .passwordTooWeak,
             .passwordTooShort,
             .passwordTooLong,
             .passwordRecentlyUsed,
             .passwordBanned,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired,
             .invalidOOBValue:
            return .init(type: .generalError)
        }
    }
}
