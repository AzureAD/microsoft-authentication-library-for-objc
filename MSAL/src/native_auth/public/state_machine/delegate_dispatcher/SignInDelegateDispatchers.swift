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

final class SignInStartDelegateDispatcher: DelegateDispatcher<SignInStartDelegate> {

    func dispatchSignInCodeRequired(
        newState: SignInCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int,
        correlationId: UUID
    ) async {
        if let onSignInCodeRequired = delegate.onSignInCodeRequired {
            telemetryUpdate?(.success(()))
            await onSignInCodeRequired(newState, sentTo, channelTargetType, codeLength)
        } else {
            let error = SignInStartError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignInCodeRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignInStartError(error: error)
        }
    }

    func dispatchSignInPasswordRequired(newState: SignInPasswordRequiredState, correlationId: UUID) async {
        if let onSignInPasswordRequired = delegate.onSignInPasswordRequired {
            telemetryUpdate?(.success(()))
            await onSignInPasswordRequired(newState)
        } else {
            let error = SignInStartError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignInPasswordRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignInStartError(error: error)
        }
    }

    func dispatchSignInCompleted(result: MSALNativeAuthUserAccountResult, correlationId: UUID) async {
        if let onSignInCompleted = delegate.onSignInCompleted {
            telemetryUpdate?(.success(()))
            await onSignInCompleted(result)
        } else {
            let error = SignInStartError(type: .generalError, message: requiredErrorMessage(for: "onSignInCompleted"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignInStartError(error: error)
        }
    }
}

final class SignInPasswordRequiredDelegateDispatcher: DelegateDispatcher<SignInPasswordRequiredDelegate> {

    func dispatchSignInCompleted(result: MSALNativeAuthUserAccountResult, correlationId: UUID) async {
        if let onSignInCompleted = delegate.onSignInCompleted {
            telemetryUpdate?(.success(()))
            await onSignInCompleted(result)
        } else {
            let error = PasswordRequiredError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignInCompleted"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignInPasswordRequiredError(error: error, newState: nil)
        }
    }
}

final class SignInResendCodeDelegateDispatcher: DelegateDispatcher<SignInResendCodeDelegate> {

    func dispatchSignInResendCodeCodeRequired(
        newState: SignInCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int,
        correlationId: UUID
    ) async {
        if let onSignInResendCodeCodeRequired = delegate.onSignInResendCodeCodeRequired {
            telemetryUpdate?(.success(()))
            await onSignInResendCodeCodeRequired(newState, sentTo, channelTargetType, codeLength)
        } else {
            let error = ResendCodeError(message: requiredErrorMessage(for: "onSignInResendCodeCodeRequired"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignInResendCodeError(error: error, newState: nil)
        }
    }
}

final class SignInVerifyCodeDelegateDispatcher: DelegateDispatcher<SignInVerifyCodeDelegate> {

    func dispatchSignInCompleted(result: MSALNativeAuthUserAccountResult, correlationId: UUID) async {
        if let onSignInCompleted = delegate.onSignInCompleted {
            telemetryUpdate?(.success(()))
            await onSignInCompleted(result)
        } else {
            let error = VerifyCodeError(type: .generalError, message: requiredErrorMessage(for: "onSignInCompleted"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignInVerifyCodeError(error: error, newState: nil)
        }
    }
}
