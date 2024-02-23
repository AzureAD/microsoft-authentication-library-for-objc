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

final class SignUpStartDelegateDispatcher: DelegateDispatcher<SignUpStartDelegate> {

    func dispatchSignUpCodeRequired(
        newState: SignUpCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int,
        correlationId: UUID
    ) async {
        if let onSignUpCodeRequired = delegate.onSignUpCodeRequired {
            telemetryUpdate?(.success(()))
            await onSignUpCodeRequired(newState, sentTo, channelTargetType, codeLength)
        } else {
            let error = SignUpStartError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpCodeRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpStartError(error: error)
        }
    }

    func dispatchSignUpAttributesInvalid(attributeNames: [String], correlationId: UUID) async {
        if let onSignUpAttributesInvalid = delegate.onSignUpAttributesInvalid {
            telemetryUpdate?(.success(()))
            await onSignUpAttributesInvalid(attributeNames)
        } else {
            let error = SignUpStartError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpAttributesInvalid"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpStartError(error: error)
        }
    }
}

final class SignUpVerifyCodeDelegateDispatcher: DelegateDispatcher<SignUpVerifyCodeDelegate> {

    func dispatchSignUpAttributesRequired(
        attributes: [MSALNativeAuthRequiredAttribute],
        newState: SignUpAttributesRequiredState,
        correlationId: UUID
    ) async {
        if let onSignUpAttributesRequired = delegate.onSignUpAttributesRequired {
            telemetryUpdate?(.success(()))
            await onSignUpAttributesRequired(attributes, newState)
        } else {
            let error = VerifyCodeError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpAttributesRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpVerifyCodeError(error: error, newState: nil)
        }
    }

    func dispatchSignUpPasswordRequired(newState: SignUpPasswordRequiredState, correlationId: UUID) async {
        if let onSignUpPasswordRequired = delegate.onSignUpPasswordRequired {
            telemetryUpdate?(.success(()))
            await onSignUpPasswordRequired(newState)
        } else {
            let error = VerifyCodeError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpPasswordRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpVerifyCodeError(error: error, newState: nil)
        }
    }

    func dispatchSignUpCompleted(newState: SignInAfterSignUpState, correlationId: UUID) async {
        if let onSignUpCompleted = delegate.onSignUpCompleted {
            telemetryUpdate?(.success(()))
            await onSignUpCompleted(newState)
        } else {
            let error = VerifyCodeError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpCompleted"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpVerifyCodeError(error: error, newState: nil)
        }
    }
}

final class SignUpResendCodeDelegateDispatcher: DelegateDispatcher<SignUpResendCodeDelegate> {

    func dispatchSignUpResendCodeCodeRequired(
        newState: SignUpCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int,
        correlationId: UUID
    ) async {
        if let onSignUpResendCodeCodeRequired = delegate.onSignUpResendCodeCodeRequired {
            telemetryUpdate?(.success(()))
            await onSignUpResendCodeCodeRequired(newState, sentTo, channelTargetType, codeLength)
        } else {
            let error = ResendCodeError(message: requiredErrorMessage(for: "onSignUpResendCodeCodeRequired"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpResendCodeError(error: error, newState: nil)
        }
    }
}

final class SignUpPasswordRequiredDelegateDispatcher: DelegateDispatcher<SignUpPasswordRequiredDelegate> {

    func dispatchSignUpAttributesRequired(
        attributes: [MSALNativeAuthRequiredAttribute],
        newState: SignUpAttributesRequiredState,
        correlationId: UUID
    ) async {
        if let onSignUpAttributesRequired = delegate.onSignUpAttributesRequired {
            telemetryUpdate?(.success(()))
            await onSignUpAttributesRequired(attributes, newState)
        } else {
            let error = PasswordRequiredError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpAttributesRequired"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpPasswordRequiredError(error: error, newState: nil)
        }
    }

    func dispatchSignUpCompleted(newState: SignInAfterSignUpState, correlationId: UUID) async {
        if let onSignUpCompleted = delegate.onSignUpCompleted {
            telemetryUpdate?(.success(()))
            await onSignUpCompleted(newState)
        } else {
            let error = PasswordRequiredError(
                type: .generalError,
                message: requiredErrorMessage(for: "onSignUpCompleted"),
                correlationId: correlationId
            )
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpPasswordRequiredError(error: error, newState: nil)
        }
    }
}

final class SignUpAttributesRequiredDelegateDispatcher: DelegateDispatcher<SignUpAttributesRequiredDelegate> {

    func dispatchSignUpAttributesRequired(
        attributes: [MSALNativeAuthRequiredAttribute],
        newState: SignUpAttributesRequiredState,
        correlationId: UUID
    ) async {
        if let onSignUpAttributesRequired = delegate.onSignUpAttributesRequired {
            telemetryUpdate?(.success(()))
            await onSignUpAttributesRequired(attributes, newState)
        } else {
            let error = AttributesRequiredError(message: requiredErrorMessage(for: "onSignUpAttributesRequired"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpAttributesRequiredError(error: error)
        }
    }

    func dispatchSignUpAttributesInvalid(attributeNames: [String], newState: SignUpAttributesRequiredState, correlationId: UUID) async {
        if let onSignUpAttributesInvalid = delegate.onSignUpAttributesInvalid {
            telemetryUpdate?(.success(()))
            await onSignUpAttributesInvalid(attributeNames, newState)
        } else {
            let error = AttributesRequiredError(message: requiredErrorMessage(for: "onSignUpAttributesInvalid"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpAttributesRequiredError(error: error)
        }
    }

    func dispatchSignUpCompleted(newState: SignInAfterSignUpState, correlationId: UUID) async {
        if let onSignUpCompleted = delegate.onSignUpCompleted {
            telemetryUpdate?(.success(()))
            await onSignUpCompleted(newState)
        } else {
            let error = AttributesRequiredError(message: requiredErrorMessage(for: "onSignUpCompleted"), correlationId: correlationId)
            telemetryUpdate?(.failure(error))
            await delegate.onSignUpAttributesRequiredError(error: error)
        }
    }
}
