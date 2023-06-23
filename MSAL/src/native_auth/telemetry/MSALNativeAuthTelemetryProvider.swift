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
protocol MSALNativeAuthTelemetryProviding {
    func telemetryForSignUp(
        type: MSALNativeAuthSignUpType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForSignIn(
        type: MSALNativeAuthSignInType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForToken(
        type: MSALNativeAuthTokenType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForResetPassword(
        type: MSALNAtiveAuthResetPasswordType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForResetPasswordStart(
        type: MSALNativeAuthResetPasswordStartType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForResendCode(
        type: MSALNativeAuthResendCodeType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForVerifyCode(
        type: MSALNativeAuthVerifyCodeType) -> MSALNativeAuthCurrentRequestTelemetry
    func telemetryForSignOut(
        type: MSALNativeAuthSignOutType) -> MSALNativeAuthCurrentRequestTelemetry
}

class MSALNativeAuthTelemetryProvider: MSALNativeAuthTelemetryProviding {
    func telemetryForSignUp(
        type: MSALNativeAuthSignUpType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdSignUpCodeStart,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForSignIn(
        type: MSALNativeAuthSignInType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdSignInWithCodeStart,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForToken(
        type: MSALNativeAuthTokenType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdToken,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForResetPassword(type: MSALNAtiveAuthResetPasswordType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdResetPassword,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForResetPasswordStart(
        type: MSALNativeAuthResetPasswordStartType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdResetPasswordStart,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForResendCode(
        type: MSALNativeAuthResendCodeType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdResendCode,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForVerifyCode(
        type: MSALNativeAuthVerifyCodeType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdVerifyCode,
            operationType: type.rawValue,
            platformFields: nil)
    }

    func telemetryForSignOut(
        type: MSALNativeAuthSignOutType) -> MSALNativeAuthCurrentRequestTelemetry {
        return MSALNativeAuthCurrentRequestTelemetry(
            apiId: .telemetryApiIdSignOut,
            operationType: type.rawValue,
            platformFields: nil)
    }
}
