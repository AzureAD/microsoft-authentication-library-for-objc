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

protocol MSALNativeAuthRequestProviding {
    func signUpRequest(
        parameters: MSALNativeAuthSignUpParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpRequest

    func signUpOTPRequest(
        parameters: MSALNativeAuthSignUpOTPParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpRequest

    func signInRequest(
        parameters: MSALNativeAuthSignInParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInRequest

    func signInOTPRequest(
        parameters: MSALNativeAuthSignInOTPParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInRequest

    func resendCodeRequest(
        parameters: MSALNativeAuthResendCodeParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthResendCodeRequest

    func verifyCodeRequest(
        parameters: MSALNativeAuthVerifyCodeParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthVerifyCodeRequest
}

final class MSALNativeAuthRequestProvider: MSALNativeAuthRequestProviding {

    // MARK: - Variables

    private let config: MSALNativeAuthConfiguration
    private let telemetryProvider: MSALNativeAuthTelemetryProviding

    // MARK: - Init

    init(
        config: MSALNativeAuthConfiguration,
        telemetryProvider: MSALNativeAuthTelemetryProviding = MSALNativeAuthTelemetryProvider()
    ) {
        self.config = config
        self.telemetryProvider = telemetryProvider
    }

    // MARK: - Sign Up with password

    func signUpRequest(
        parameters: MSALNativeAuthSignUpParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpRequest {

        guard let attributes = try formatAttributes(parameters.attributes) else {
            throw MSALNativeAuthError.invalidAttributes
        }

        let params = MSALNativeAuthSignUpRequestParameters(
            config: config,
            email: parameters.email,
            password: parameters.password,
            attributes: attributes,
            scope: formatScope(parameters.scopes),
            context: context,
            grantType: .password
        )

        let request = try MSALNativeAuthSignUpRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpWithPassword),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context, encoding: .json),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - Sign Up with OTP

    func signUpOTPRequest(
        parameters: MSALNativeAuthSignUpOTPParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpRequest {

        guard let attributes = try formatAttributes(parameters.attributes) else {
            throw MSALNativeAuthError.invalidAttributes
        }

        let params = MSALNativeAuthSignUpRequestParameters(
            config: config,
            email: parameters.email,
            attributes: attributes,
            scope: formatScope(parameters.scopes),
            context: context,
            grantType: .otp
        )

        let request = try MSALNativeAuthSignUpRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpWithPassword),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context, encoding: .json),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - SignIn with Password

    func signInRequest(
        parameters: MSALNativeAuthSignInParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInRequest {

        let params = MSALNativeAuthSignInRequestParameters(
            config: config,
            email: parameters.email,
            password: parameters.password,
            scope: formatScope(parameters.scopes),
            context: context,
            grantType: .password
        )

        let request = try MSALNativeAuthSignInRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInWithPassword),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context, encoding: .json),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - SignIn with OTP

    func signInOTPRequest(
        parameters: MSALNativeAuthSignInOTPParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInRequest {

        let params = MSALNativeAuthSignInRequestParameters(
            config: config,
            email: parameters.email,
            scope: formatScope(parameters.scopes),
            context: context,
            grantType: .otp
        )

        let request = try MSALNativeAuthSignInRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInWithOTP),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context, encoding: .json),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - Resend Code

    func resendCodeRequest(
        parameters: MSALNativeAuthResendCodeParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthResendCodeRequest {

        let params = MSALNativeAuthResendCodeRequestParameters(
            config: config,
            credentialToken: parameters.credentialToken,
            context: context
        )

        let request = try MSALNativeAuthResendCodeRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResendCode(type: .resendCode),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context, encoding: .json),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - Verify Code

    func verifyCodeRequest(
        parameters: MSALNativeAuthVerifyCodeParameters,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthVerifyCodeRequest {

        let params = MSALNativeAuthVerifyCodeRequestParameters(
            config: config,
            credentialToken: parameters.credentialToken,
            otp: parameters.otp,
            context: context
        )

        let request = try MSALNativeAuthVerifyCodeRequest(params: params)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForVerifyCode(type: .verifyCode),
            context: context)

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: params.context, encoding: .json),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    private func formatAttributes(_ attributes: [String: Any]) throws -> String? {
        let data = try JSONSerialization.data(withJSONObject: attributes)
        return String(data: data, encoding: .utf8)
    }

    private func formatScope(_ scope: [String]) -> String {
        return scope.joined(separator: ",")
    }
}
