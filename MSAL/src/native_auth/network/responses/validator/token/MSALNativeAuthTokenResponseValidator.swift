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
        context: MSIDRequestContext,
        msidConfiguration: MSIDConfiguration,
        result: Result<MSIDCIAMTokenResponse, Error>
    ) -> MSALNativeAuthTokenValidatedResponse

    func validateAccount(
        with tokenResult: MSIDTokenResult,
        context: MSIDRequestContext,
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
        context: MSIDRequestContext,
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
                    format: "Token: Unable to decode error response: \(tokenResponseError)")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedTokenResult(context, tokenResponseError)
        }
    }

    func validateAccount(
        with tokenResult: MSIDTokenResult,
        context: MSIDRequestContext,
        accountIdentifier: MSIDAccountIdentifier
    ) throws -> Bool {
        var error: NSError?
        let validAccount = msidValidator.validateAccount(
            accountIdentifier,
            tokenResult: tokenResult,
            correlationID: context.correlationId(),
            error: &error
        )
        if let error = error {
            throw error
        }
        return validAccount
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func handleFailedTokenResult(
        _ context: MSIDRequestContext,
        _ responseError: MSALNativeAuthTokenResponseError) -> MSALNativeAuthTokenValidatedResponse {
            switch responseError.error {
            case .invalidRequest:
                return handleInvalidRequestErrorCodes(apiError: responseError, context: context)
            case .invalidClient,
                .unauthorizedClient:
                return .error(.unauthorizedClient(responseError))
            case .invalidGrant:
                if responseError.subError == .invalidOOBValue {
                    return .error(.invalidOOBCode(responseError))
                } else {
                    return handleInvalidGrantErrorCodes(apiError: responseError, context: context)
                }
            case .expiredToken:
                return .error(.expiredToken(responseError))
            case .expiredRefreshToken:
                return .error(.expiredRefreshToken(responseError))
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType(responseError))
            case .invalidScope:
                return .error(.invalidScope(responseError))
            case .authorizationPending:
                return .error(.authorizationPending(responseError))
            case .slowDown:
                return .error(.slowDown(responseError))
            case .userNotFound:
                return .error(.userNotFound(responseError))
            case .unknown:
                return .error(.unexpectedError(responseError))
            }
        }

    private func handleInvalidRequestErrorCodes(
        apiError: MSALNativeAuthTokenResponseError,
        context: MSIDRequestContext
    ) -> MSALNativeAuthTokenValidatedResponse {
        return handleInvalidResponseErrorCodes(
            apiError,
            context: context,
            useInvalidRequestAsDefaultResult: true,
            errorCodesConverterFunction: convertInvalidRequestErrorCodeToErrorType
        )
    }

    private func handleInvalidGrantErrorCodes(
        apiError: MSALNativeAuthTokenResponseError,
        context: MSIDRequestContext
    ) -> MSALNativeAuthTokenValidatedResponse {
        return handleInvalidResponseErrorCodes(apiError, context: context, errorCodesConverterFunction: convertInvalidGrantErrorCodeToErrorType)
    }

    private func handleInvalidResponseErrorCodes(
        _ apiError: MSALNativeAuthTokenResponseError,
        context: MSIDRequestContext,
        useInvalidRequestAsDefaultResult: Bool = false,
        errorCodesConverterFunction: (MSALNativeAuthESTSApiErrorCodes, MSALNativeAuthTokenResponseError) -> MSALNativeAuthTokenValidatedErrorType
    ) -> MSALNativeAuthTokenValidatedResponse {
        guard var errorCodes = apiError.errorCodes, !errorCodes.isEmpty else {
            MSALLogger.log(level: .error, context: context, format: "/token error - Empty error_codes received")
            return useInvalidRequestAsDefaultResult ? .error(.invalidRequest(apiError)) : .error(.generalError(apiError))
        }

        let validatedResponse: MSALNativeAuthTokenValidatedResponse
        let firstErrorCode = errorCodes.removeFirst()

        if let knownErrorCode = MSALNativeAuthESTSApiErrorCodes(rawValue: firstErrorCode) {
            validatedResponse = .error(errorCodesConverterFunction(knownErrorCode, apiError))
        } else {
            MSALLogger.log(level: .error, context: context, format: "/token error - Unknown code received in error_codes: \(firstErrorCode)")
            validatedResponse = useInvalidRequestAsDefaultResult ? .error(.invalidRequest(apiError)) : .error(.generalError(apiError))
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

    private func convertInvalidGrantErrorCodeToErrorType(
        _ errorCode: MSALNativeAuthESTSApiErrorCodes,
        _ apiError: MSALNativeAuthTokenResponseError
    ) -> MSALNativeAuthTokenValidatedErrorType {
        switch errorCode {
        case .userNotFound:
            return .userNotFound(apiError)
        case .invalidCredentials:
            return .invalidPassword(apiError)
        case .strongAuthRequired:
            return .strongAuthRequired(apiError)
        case .userNotHaveAPassword,
             .invalidRequestParameter:
            return .generalError(apiError)
        }
    }

    private func convertInvalidRequestErrorCodeToErrorType(
        _ errorCode: MSALNativeAuthESTSApiErrorCodes,
        _ apiError: MSALNativeAuthTokenResponseError
    ) -> MSALNativeAuthTokenValidatedErrorType {
        switch errorCode {
        case .userNotFound,
            .invalidCredentials,
            .strongAuthRequired,
            .userNotHaveAPassword,
            .invalidRequestParameter:
            return .invalidRequest(apiError)
        }
    }
}
