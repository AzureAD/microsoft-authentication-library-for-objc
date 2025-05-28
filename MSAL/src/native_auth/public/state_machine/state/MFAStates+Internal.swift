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

extension MFABaseState {
    func requestChallengeInternal(authMethod: MSALAuthMethod?) async -> MSALNativeAuthMFAControlling.MFARequestChallengeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALNativeAuthLogger.log(level: .info, context: context, format: "MFA, request challenge")
        return await controller.requestChallenge(
            continuationToken: continuationToken,
            authMethod: authMethod,
            context: context,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson
        )
    }
}

extension MFARequiredState {
    func getAuthMethodsInternal() async -> MSALNativeAuthMFAControlling.MFAGetAuthMethodsControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALNativeAuthLogger.log(level: .info, context: context, format: "MFA, get authentication methods")
        return await controller.getAuthMethods(
            continuationToken: continuationToken,
            context: context,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson
        )
    }

    func submitChallengeInternal(challenge: String) async -> MSALNativeAuthMFAControlling.MFASubmitChallengeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALNativeAuthLogger.log(level: .info, context: context, format: "MFA, submit challenge")
        guard inputValidator.isInputValid(challenge) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "MFA, invalid challenge")
            return .init(
                .error(error: MFASubmitChallengeError(type: .invalidChallenge, correlationId: correlationId), newState: self),
                correlationId: context.correlationId()
            )
        }
        return await controller.submitChallenge(
            challenge: challenge,
            continuationToken: continuationToken,
            context: context,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson
        )
    }
}
