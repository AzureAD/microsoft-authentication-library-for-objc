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

struct MSALNativeAuthSignUpContinueResponseError: MSALNativeAuthResponseError {
    let error: MSALNativeAuthSignUpContinueOauth2ErrorCode
    let subError: MSALNativeAuthSubErrorCode?
    let errorDescription: String?
    let errorCodes: [Int]?
    let errorURI: String?
    let innerErrors: [MSALNativeAuthInnerError]?
    let continuationToken: String?
    let requiredAttributes: [MSALNativeAuthRequiredAttributeInternal]?
    let unverifiedAttributes: [MSALNativeAuthErrorBasicAttribute]?
    let invalidAttributes: [MSALNativeAuthErrorBasicAttribute]?
    var correlationId: UUID?

    enum CodingKeys: String, CodingKey {
        case error
        case subError = "suberror"
        case errorDescription = "error_description"
        case errorCodes = "error_codes"
        case errorURI = "error_uri"
        case innerErrors = "inner_errors"
        case continuationToken = "continuation_token"
        case requiredAttributes = "required_attributes"
        case unverifiedAttributes = "unverified_attributes"
        case invalidAttributes = "invalid_attributes"
        case correlationId
    }

    init(
        error: MSALNativeAuthSignUpContinueOauth2ErrorCode = .unknown,
        subError: MSALNativeAuthSubErrorCode? = nil,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        continuationToken: String? = nil,
        requiredAttributes: [MSALNativeAuthRequiredAttributeInternal]? = nil,
        unverifiedAttributes: [MSALNativeAuthErrorBasicAttribute]? = nil,
        invalidAttributes: [MSALNativeAuthErrorBasicAttribute]? = nil,
        correlationId: UUID? = nil
    ) {
        self.error = error
        self.subError = subError
        self.errorDescription = errorDescription
        self.errorCodes = errorCodes
        self.errorURI = errorURI
        self.innerErrors = innerErrors
        self.continuationToken = continuationToken
        self.requiredAttributes = requiredAttributes
        self.unverifiedAttributes = unverifiedAttributes
        self.invalidAttributes = invalidAttributes
        self.correlationId = correlationId
    }
}

extension MSALNativeAuthSignUpContinueResponseError {

    func toVerifyCodePublicError(correlationId: UUID) -> VerifyCodeError {
        switch error {
        case .invalidGrant:
            return .init(
                type: subError == .invalidOOBValue ? .invalidCode : .generalError,
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )
        case .unauthorizedClient,
             .expiredToken,
             .invalidRequest,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired,
             .unknown:
            return .init(
                type: .generalError,
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )
        }
    }

    func toPasswordRequiredPublicError(correlationId: UUID) -> PasswordRequiredError {
        switch error {
        case .invalidGrant:
            return .init(
                type: subError?.isAnyPasswordError == true ? .invalidPassword : .generalError,
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )

        case .unauthorizedClient,
             .expiredToken,
             .invalidRequest,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired,
             .unknown:
            return .init(
                type: .generalError,
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )
        }
    }

    func toAttributesRequiredPublicError(correlationId: UUID, message: String? = nil) -> AttributesRequiredError {
        return AttributesRequiredError(
            type: .generalError,
            message: message ?? errorDescription,
            correlationId: correlationId,
            errorCodes: errorCodes ?? [],
            errorUri: errorURI
        )
    }
}
