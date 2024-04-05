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

final class ResetPasswordStartDelegateDispatcher: DelegateDispatcher<ResetPasswordStartDelegate> {

    func dispatchResetPasswordCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int,
        correlationId: UUID
    ) async {
        if let onResetPasswordCodeRequired = delegate.onResetPasswordCodeRequired {
            telemetryUpdate?(.success(()))
            await onResetPasswordCodeRequired(newState, sentTo, channelTargetType, codeLength)
        } else {
            let error = ResetPasswordStartError(
                type: .generalError,
                message: requiredErrorMessage(for: "onResetPasswordCodeRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onResetPasswordStartError(error: error)
        }
    }
}

final class ResetPasswordVerifyCodeDelegateDispatcher: DelegateDispatcher<ResetPasswordVerifyCodeDelegate> {

    func dispatchPasswordRequired(newState: ResetPasswordRequiredState, correlationId: UUID) async {
        if let onPasswordRequired = delegate.onPasswordRequired {
            telemetryUpdate?(.success(()))
            await onPasswordRequired(newState)
        } else {
            let error = VerifyCodeError(type: .generalError, message: requiredErrorMessage(for: "onPasswordRequired"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onResetPasswordVerifyCodeError(error: error, newState: nil)
        }
    }
}

final class ResetPasswordResendCodeDelegateDispatcher: DelegateDispatcher<ResetPasswordResendCodeDelegate> {

    func dispatchResetPasswordResendCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int,
        correlationId: UUID
    ) async {
        if let onResetPasswordResendCodeRequired = delegate.onResetPasswordResendCodeRequired {
            telemetryUpdate?(.success(()))
            await onResetPasswordResendCodeRequired(newState, sentTo, channelTargetType, codeLength)
        } else {
            let error = ResendCodeError(message: requiredErrorMessage(for: "onResetPasswordResendCodeRequired"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onResetPasswordResendCodeError(error: error, newState: nil)
        }
    }
}

final class ResetPasswordRequiredDelegateDispatcher: DelegateDispatcher<ResetPasswordRequiredDelegate> {

    func dispatchResetPasswordCompleted(newState: SignInAfterResetPasswordState, correlationId: UUID) async {
        if let onResetPasswordCompleted = delegate.onResetPasswordCompleted {
            telemetryUpdate?(.success(()))
            await onResetPasswordCompleted(newState)
        } else {
            let error = PasswordRequiredError(
                type: .generalError,
                message: requiredErrorMessage(for: "onResetPasswordCompleted"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onResetPasswordRequiredError(error: error, newState: nil)
        }
    }
}
