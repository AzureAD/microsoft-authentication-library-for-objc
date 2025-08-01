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

enum MSALNativeAuthJITIntrospectValidatedResponse {
    case authMethodsRetrieved(continuationToken: String, authMethods: [MSALNativeAuthInternalAuthenticationMethod])
    case error(MSALNativeAuthJITIntrospectValidatedErrorType)
}

enum MSALNativeAuthJITIntrospectValidatedErrorType: Error {
    case redirect(reason: String?)
    case invalidRequest(MSALNativeAuthJITIntrospectResponseError)
    case unexpectedError(MSALNativeAuthJITIntrospectResponseError?)

    func convertToSignInPasswordStartError(correlationId: UUID) -> SignInStartError {
        switch self {
        case .invalidRequest(let apiError):
            return .init(
                type: .generalError,
                message: apiError.errorDescription ?? "",
                correlationId: correlationId,
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI ?? ""
            )
        case .unexpectedError(let apiError):
            return .init(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: correlationId,
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
        case .redirect(reason: let reason):
            return .init(
                type: .browserRequired,
                message: reason,
                correlationId: correlationId
            )
        }
    }

    func convertToVerifyCodeError(correlationId: UUID) -> VerifyCodeError {
        switch self {
        case .invalidRequest(let apiError):
            return .init(
                type: .generalError,
                message: apiError.errorDescription ?? "",
                correlationId: correlationId,
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI ?? ""
            )
        case .unexpectedError(let apiError):
            return .init(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: correlationId,
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
        case .redirect(reason: let reason):
            return .init(
                type: .browserRequired,
                message: reason,
                correlationId: correlationId
            )
        }
    }

    func convertToPasswordRequiredError(correlationId: UUID) -> PasswordRequiredError {
        return PasswordRequiredError(signInStartError: convertToSignInPasswordStartError(correlationId: correlationId))
    }
}
