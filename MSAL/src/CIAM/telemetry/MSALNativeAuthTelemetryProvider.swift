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
class MSALNativeAuthTelemetryProvider {
    static func telemetryForSignUp(
        type: MSALNativeAuthSignUpType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdSignUp,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForSignIn(
        type: MSALNativeAuthSignInType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdSignIn,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForRefreshToken(
        type: MSALNativeAuthTokenRefreshType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdRefreshToken,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForResetPasswordStart(
        type: MSALNativeAuthResetPasswordStartType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdResetPasswordStart,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForResetPasswordComplete(
        type: MSALNativeAuthResetPasswordCompleteType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdResetPasswordComplete,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForResendCode(
        type: MSALNativeAuthResendCodeType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdResendCode,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForVerifyCode(
        type: MSALNativeAuthVerifyCodeType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdVerifyCode,
                operationType: type.rawValue,
                platformFields: nil)
        }

    static func telemetryForSignOut(
        type: MSALNativeAuthSignOutType) -> MSALNativeAuthCurrentRequestTelemetry {
            return MSALNativeAuthCurrentRequestTelemetry(
                apiId: .telemetryApiIdSignOut,
                operationType: type.rawValue,
                platformFields: nil)
        }
}
