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

protocol MSALNativeAuthV2RequestProviding {

    /// Submit a phone number or email address at the server's `enroll` href.
    func enroll(
        href: String,
        verificationContact: String,
        channelType: MSALNativeAuthV2EnrollmentMethod.ChannelType,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Activate the enrolled method at the server's `activate` href.
    func activate(
        href: String,
        otp: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// SSPR entry, posted to the authorize-challenge `reset_password` href.
    func resetPasswordStart(username: String,
                            continuationToken: String,
                            href: String,
                            apiId: MSALNativeAuthTelemetryApiId,
                            context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Sign-in entry, posted to the authorize-challenge `sign_in` href.
    func signInStart(username: String,
                     continuationToken: String,
                     href: String,
                     apiId: MSALNativeAuthTelemetryApiId,
                     context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Sign-up entry, posted to the authorize-challenge `sign_up` href.
    func signUpStart(username: String,
                     continuationToken: String,
                     href: String,
                     apiId: MSALNativeAuthTelemetryApiId,
                     context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Submit collected user attributes during sign up (server `submitAttributes` href).
    func submitAttributes(href: String,
                          attributes: [String: Any],
                          continuationToken: String,
                          apiId: MSALNativeAuthTelemetryApiId,
                          context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Send EOTP (server `challenge` / `resend` href).
    func challenge(href: String,
                   continuationToken: String,
                   apiId: MSALNativeAuthTelemetryApiId,
                   context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Verify OTP (server `verify` href).
    func verify(href: String,
                otp: String,
                continuationToken: String,
                apiId: MSALNativeAuthTelemetryApiId,
                context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Submit password (server `verify` href).
    func submitPassword(href: String,
                        password: String,
                        continuationToken: String,
                        apiId: MSALNativeAuthTelemetryApiId,
                        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Update password (server `update` href, PUT).
    func updatePassword(href: String,
                        newPassword: String,
                        continuationToken: String,
                        apiId: MSALNativeAuthTelemetryApiId,
                        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Poll for completion (server `poll` href).
    func poll(href: String,
              continuationToken: String,
              apiId: MSALNativeAuthTelemetryApiId,
              context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Complete server-directed SSPR phone-risk verification.
    func riskVerify(href: String,
                    continuationToken: String,
                    apiId: MSALNativeAuthTelemetryApiId,
                    context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Start `authorize-challenge` (no continuation token) → `401` + continuation token.
    func authorizeChallengeStart(scopes: [String]?,
                                 claimsRequestJson: String?,
                                 apiId: MSALNativeAuthTelemetryApiId,
                                 context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Continue `authorize-challenge` (with continuation token) → authorization code.
    func authorizeChallengeContinue(continuationToken: String,
                                    apiId: MSALNativeAuthTelemetryApiId,
                                    context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol

    /// Token exchange.
    func token(code: String,
               scopes: [String],
               claimsRequestJson: String?,
               apiId: MSALNativeAuthTelemetryApiId,
               context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol
}

final class MSALNativeAuthV2RequestProvider: MSALNativeAuthV2RequestProviding {

    private let config: MSALNativeAuthInternalConfiguration
    private let configurator: MSALNativeAuthV2RequestConfigurator

    init(config: MSALNativeAuthInternalConfiguration) {
        self.config = config
        self.configurator = MSALNativeAuthV2RequestConfigurator(config: config)
    }

    func enroll(
        href: String,
        verificationContact: String,
        channelType: MSALNativeAuthV2EnrollmentMethod.ChannelType,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.registerMethod.rawValue,
            requestBody: MSALNativeAuthV2EnrollRequestBody(
                continuationToken: continuationToken,
                verificationContact: verificationContact,
                channelType: channelType
            )
        ))
    }

    func activate(
        href: String,
        otp: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.submitCode.rawValue,
            requestBody: MSALNativeAuthV2VerifyRequestBody(continuationToken: continuationToken, otp: otp)
        ))
    }

    func resetPasswordStart(username: String,
                            continuationToken: String,
                            href: String,
                            apiId: MSALNativeAuthTelemetryApiId,
                            context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2EntryParameters(
            context: context,
            target: .href(href),
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.resetPasswordStart.rawValue,
            username: username,
            continuationToken: continuationToken
        ))
    }

    func signInStart(username: String,
                     continuationToken: String,
                     href: String,
                     apiId: MSALNativeAuthTelemetryApiId,
                     context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2EntryParameters(
            context: context,
            target: .href(href),
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.signInStart.rawValue,
            username: username,
            continuationToken: continuationToken
        ))
    }

    func signUpStart(username: String,
                     continuationToken: String,
                     href: String,
                     apiId: MSALNativeAuthTelemetryApiId,
                     context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2EntryParameters(
            context: context,
            target: .href(href),
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.signUpStart.rawValue,
            username: username,
            continuationToken: continuationToken
        ))
    }

    func submitAttributes(href: String,
                          attributes: [String: Any],
                          continuationToken: String,
                          apiId: MSALNativeAuthTelemetryApiId,
                          context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        guard JSONSerialization.isValidJSONObject(attributes) else {
            throw MSALNativeAuthInternalError.invalidAttributes
        }
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.submitAttributes.rawValue,
            requestBody: MSALNativeAuthV2SubmitAttributesRequestBody(continuationToken: continuationToken, attributes: attributes)
        ))
    }

    func challenge(href: String,
                   continuationToken: String,
                   apiId: MSALNativeAuthTelemetryApiId,
                   context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.challenge.rawValue,
            requestBody: MSALNativeAuthV2ChallengeRequestBody(continuationToken: continuationToken)
        ))
    }

    func verify(href: String,
                otp: String,
                continuationToken: String,
                apiId: MSALNativeAuthTelemetryApiId,
                context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.verify.rawValue,
            requestBody: MSALNativeAuthV2VerifyRequestBody(continuationToken: continuationToken, otp: otp)
        ))
    }

    func submitPassword(href: String,
                        password: String,
                        continuationToken: String,
                        apiId: MSALNativeAuthTelemetryApiId,
                        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.submitPassword.rawValue,
            requestBody: MSALNativeAuthV2SubmitPasswordRequestBody(continuationToken: continuationToken, password: password)
        ))
    }

    func updatePassword(href: String,
                        newPassword: String,
                        continuationToken: String,
                        apiId: MSALNativeAuthTelemetryApiId,
                        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "PUT",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.updatePassword.rawValue,
            requestBody: MSALNativeAuthV2UpdatePasswordRequestBody(continuationToken: continuationToken, newPassword: newPassword)
        ))
    }

    func poll(href: String,
              continuationToken: String,
              apiId: MSALNativeAuthTelemetryApiId,
              context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.poll.rawValue,
            requestBody: MSALNativeAuthV2PollRequestBody(continuationToken: continuationToken)
        ))
    }

    func riskVerify(href: String,
                    continuationToken: String,
                    apiId: MSALNativeAuthTelemetryApiId,
                    context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: apiId,
            operationType: MSALNativeAuthV2OperationType.riskVerify.rawValue,
            requestBody: MSALNativeAuthV2RequestBody(continuationToken: continuationToken)
        ))
    }

    func authorizeChallengeStart(scopes: [String]? = nil,
                                 claimsRequestJson: String? = nil,
                                 apiId: MSALNativeAuthTelemetryApiId,
                                 context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(
            parameters: MSALNativeAuthV2AuthorizeChallengeStartParameters(
                context: context,
                clientId: config.clientId,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                apiId: apiId
            )
        )
    }

    func authorizeChallengeContinue(continuationToken: String,
                                    apiId: MSALNativeAuthTelemetryApiId,
                                    context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(
            parameters: MSALNativeAuthV2AuthorizeChallengeContinueParameters(
                context: context,
                continuationToken: continuationToken,
                apiId: apiId
            )
        )
    }

    func token(code: String,
               scopes: [String],
               claimsRequestJson: String?,
               apiId: MSALNativeAuthTelemetryApiId,
               context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        return try configurator.configure(parameters: MSALNativeAuthV2TokenParameters(
            context: context,
            clientId: config.clientId,
            code: code,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            apiId: apiId
        ))
    }
}
