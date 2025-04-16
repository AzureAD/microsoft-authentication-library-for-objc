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

extension RegisterStrongAuthBaseState {
    func requestChallengeInternal(authMethod: MSALAuthMethod,
                                  verificationContact: String?) async -> MSALNativeAuthJITControlling.JITRequestChallengeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .warning, context: context, format: MSALNativeAuthLogMessage.privatePreviewLog)
        MSALLogger.log(level: .info, context: context, format: "JIT, request challenge")
        return await controller.requestJITChallenge(username: username,
                                                    continuationToken: continuationToken,
                                                    scopes: scopes,
                                                    claimsRequestJson: claimsRequestJson,
                                                    authMethod: authMethod,
                                                    verificationContact: verificationContact,
                                                    context: context)
    }
}

extension RegisterStrongAuthVerificationRequiredState {

    func submitChallengeInternal(challenge: String) async -> MSALNativeAuthJITControlling.JITSubmitChallengeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .warning, context: context, format: MSALNativeAuthLogMessage.privatePreviewLog)
        MSALLogger.log(level: .info, context: context, format: "JIT, submit challenge")
        guard inputValidator.isInputValid(challenge) else {
            MSALLogger.log(level: .error, context: context, format: "JIT, invalid challenge")
            return .init(
                .error(error: RegisterStrongAuthSubmitChallengeError(type: .invalidChallenge, correlationId: correlationId), newState: self),
                correlationId: context.correlationId()
            )
        }
        return await controller.submitJITChallenge(
            username: username,
            challenge: challenge ,
            continuationToken: continuationToken,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            context: context
        )
    }
}
