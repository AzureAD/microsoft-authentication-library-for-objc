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

protocol MSALNativeAuthTokenResponseValidating {
    func validate(
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration,
        result: Result<MSIDCIAMTokenResponse, Error>
    ) -> MSALNativeAuthTokenValidatedResponse

    func validateAccount(
        with tokenResult: MSIDTokenResult,
        context: MSIDRequestContext,
        configuration: MSIDConfiguration,
        accountIdentifier: MSIDAccountIdentifier
    ) throws -> Bool
}

final class MSALNativeAuthTokenResponseValidator: MSALNativeAuthTokenResponseValidating {
    private let factory: MSALNativeAuthResultBuildable
    private let msidValidator: MSIDTokenResponseValidator

    init(
        factory: MSALNativeAuthResultBuildable,
        msidValidator: MSIDTokenResponseValidator
    ) {
        self.factory = factory
        self.msidValidator = msidValidator
    }

    func validate(
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration,
        result: Result<MSIDCIAMTokenResponse, Error>
    ) -> MSALNativeAuthTokenValidatedResponse {
        switch result {
        case .success(let tokenResponse):
            return .success(tokenResponse)
        case .failure(let tokenResponseError):
            guard let tokenResponseError =
                    tokenResponseError as? MSALNativeAuthTokenResponseError else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Token: Error type not expected, error: \(tokenResponseError)")
                return .error(.invalidServerResponse)
            }
            return handleFailedTokenResult(context, tokenResponseError)
        }
    }

    func validateAccount(
        with tokenResult: MSIDTokenResult,
        context: MSIDRequestContext,
        configuration: MSIDConfiguration,
        accountIdentifier: MSIDAccountIdentifier
    ) throws -> Bool {
        var error: NSError?
        let validAccount = msidValidator.validateAccount(
            accountIdentifier,
            tokenResult: tokenResult,
            correlationID: context.correlationId(),
            error: &error
        )
        if let error {
            throw error
        }
        return validAccount
    }

    private func handleFailedTokenResult(
        _ context: MSALNativeAuthRequestContext,
        _ responseError: MSALNativeAuthTokenResponseError) -> MSALNativeAuthTokenValidatedResponse {
            switch responseError.error {
            case .invalidRequest:
                return .error(.invalidRequest)
            case .invalidClient:
                return .error(.invalidClient)
            case .invalidGrant:
                return handleInvalidGrantErrorCodes(responseError.errorCodes, context: context)
            case .expiredToken:
                return .error(.expiredToken)
            case .expiredRefreshToken:
                return .error(.expiredRefreshToken)
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType)
            case .invalidScope:
                return .error(.invalidScope)
            case .authorizationPending:
                return .error(.authorizationPending)
            case .slowDown:
                return .error(.slowDown)
            }
        }

    private func handleInvalidGrantErrorCodes(_ errorCodes: [Int]?, context: MSALNativeAuthRequestContext) -> MSALNativeAuthTokenValidatedResponse {
        guard var errorCodes = errorCodes, !errorCodes.isEmpty else {
            MSALLogger.log(level: .error, context: context, format: "/token error - Empty error_codes received")
            return .error(.generalError)
        }

        let validatedResponse: MSALNativeAuthTokenValidatedResponse
        let firstErrorCode = errorCodes.removeFirst()

        if let knownErrorCode = MSALNativeAuthESTSApiErrorCodes(rawValue: firstErrorCode) {
            validatedResponse = .error(convertErrorCodeToErrorType(knownErrorCode))
        } else {
            MSALLogger.log(level: .error, context: context, format: "/token error - Unknown code received in error_codes: \(firstErrorCode)")
            validatedResponse = .error(.generalError)
        }

        // Log the rest of error_codes

        errorCodes.forEach { errorCode in
            let errorMessage: String

            if let knownErrorCode = MSALNativeAuthESTSApiErrorCodes(rawValue: errorCode) {
                errorMessage = "/token error - ESTS error received in error_codes: \(knownErrorCode) (ignoring)"
            } else {
                errorMessage = "/token error - Unknown ESTS received in error_codes with code: \(errorCode) (ignoring)"
            }

            MSALLogger.log(level: .verbose, context: context, format: errorMessage)
        }

        return validatedResponse
    }

    private func convertErrorCodeToErrorType(_ errorCode: MSALNativeAuthESTSApiErrorCodes) -> MSALNativeAuthTokenValidatedErrorType {
        switch errorCode {
        case .userNotFound:
            return .userNotFound
        case .invalidCredentials:
            return .invalidPassword
        case .invalidOTP:
            return .invalidOOBCode
        case .strongAuthRequired:
            return .strongAuthRequired
        }
    }
}
