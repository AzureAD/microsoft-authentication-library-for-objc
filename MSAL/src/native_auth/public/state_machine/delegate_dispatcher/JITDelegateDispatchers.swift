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

final class JITRequestChallengeDelegateDispatcher: DelegateDispatcher<RegisterStrongAuthChallengeDelegate> {

    func dispatchVerificationRequired(newState: RegisterStrongAuthVerificationRequiredState,
                                      sentTo: String,
                                      channelTargetType: MSALNativeAuthChannelType,
                                      codeLength: Int,
                                      correlationId: UUID
    ) async {
        if let onRegisterStrongAuthVerificationRequired = delegate.onRegisterStrongAuthVerificationRequired {
            telemetryUpdate?(.success(()))
            let result = MSALNativeAuthRegisterStrongAuthVerificationRequiredResult(newState: newState,
                                                                                    sentTo: sentTo,
                                                                                    channelTargetType: channelTargetType,
                                                                                    codeLength: codeLength)
            await onRegisterStrongAuthVerificationRequired(result)
        } else {
            let error = RegisterStrongAuthChallengeError(
                type: .generalError,
                message: requiredErrorMessage(for: "onRegisterStrongAuthVerificationRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onRegisterStrongAuthChallengeError(error: error, newState: nil)
        }
    }
}

final class JITSubmitChallengeDelegateDispatcher: DelegateDispatcher<RegisterStrongAuthSubmitChallengeDelegate> {

    func dispatchSignInCompleted(result: MSALNativeAuthUserAccountResult, correlationId: UUID) async {
        if let onSignInCompleted = delegate.onSignInCompleted {
            telemetryUpdate?(.success(()))
            await onSignInCompleted(result)
        } else {
            let error = RegisterStrongAuthSubmitChallengeError(type: .generalError, message: requiredErrorMessage(for: "onSignInCompleted"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onRegisterStrongAuthSubmitChallengeError(error: error, newState: nil)
        }
    }
}
/*
final class MFAGetAuthMethodsDelegateDispatcher: DelegateDispatcher<MFAGetAuthMethodsDelegate> {

    func dispatchSelectionRequired(authMethods: [MSALAuthMethod], newState: MFARequiredState, correlationId: UUID) async {
        if let onSelectionRequired = delegate.onMFAGetAuthMethodsSelectionRequired {
            telemetryUpdate?(.success(()))
            await onSelectionRequired(authMethods, newState)
        } else {
            let error = MFAGetAuthMethodsError(
                type: .generalError,
                message: requiredErrorMessage(for: "onMFAGetAuthMethodsSelectionRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onMFAGetAuthMethodsError(error: error, newState: nil)
        }
    }
}

final class MFASubmitChallengeDelegateDispatcher: DelegateDispatcher<MFASubmitChallengeDelegate> {

    func dispatchSignInCompleted(result: MSALNativeAuthUserAccountResult, correlationId: UUID) async {
        if let onSignInCompleted = delegate.onSignInCompleted {
            telemetryUpdate?(.success(()))
            await onSignInCompleted(result)
        } else {
            let error = MFASubmitChallengeError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignInCompleted"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onMFASubmitChallengeError(error: error, newState: nil)
        }
    }
}
 */
