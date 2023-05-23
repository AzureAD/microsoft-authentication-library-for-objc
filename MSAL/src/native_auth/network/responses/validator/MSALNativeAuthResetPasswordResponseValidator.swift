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

@_implementationOnly import MSAL_Private

protocol MSALNativeAuthResetPasswordResponseValidating {
    func validate(_ result: Result<MSALNativeAuthResetPasswordStartResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordResponseValidator.ResetPasswordStartValidatedResponse
}

final class MSALNativeAuthResetPasswordResponseValidator: MSALNativeAuthResetPasswordResponseValidating {

    // MARK: - Start Request

    enum ResetPasswordStartValidatedResponse {
        case success(passwordResetToken: String)
        case redirect
        case error(MSALNativeAuthResetPasswordStartOauth2ErrorCode)
        case unexpectedError
    }

    func validate(_ result: Result<MSALNativeAuthResetPasswordStartResponse, Error>, with context: MSIDRequestContext) -> ResetPasswordStartValidatedResponse {
        switch result {
        case .success(let response):
            return handleStartSuccess(response, with: context)
        case .failure(let error):
            return handleStartFailed(error, with: context)
        }
    }

    private func handleStartSuccess(_ response: MSALNativeAuthResetPasswordStartResponse, with context: MSIDRequestContext) -> ResetPasswordStartValidatedResponse {
        if response.challengeType == .redirect {
            return .redirect
        } else if let passwordResetToken = response.passwordResetToken {
            return .success(passwordResetToken: passwordResetToken)
        } else {
            MSALLogger.log(level: .error,
                           context: context,
                           filename: #fileID,
                           lineNumber: #line,
                           function: #function,
                           format: "Error type not expected")

            return .unexpectedError
        }
    }

    private func handleStartFailed(_ error: Error, with context: MSIDRequestContext) -> ResetPasswordStartValidatedResponse {
        guard let apiError = error as? MSALNativeAuthResetPasswordStartResponseError else {
            MSALLogger.log(level: .error,
                           context: context,
                           filename: #fileID,
                           lineNumber: #line,
                           function: #function,
                           format: "Error type not expected")
            
            return .unexpectedError
        }

        return .error(apiError.error)
    }

}
