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

protocol MSALNativeAuthRequestSignUpProviding {
    func start(
        parameters: MSALNativeAuthSignUpParameters,
        challengeTypes: [MSALNativeAuthChallengeType],
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpStartRequest

    func challenge(
        token: String,
        challengeTypes: [MSALNativeAuthChallengeType],
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpChallengeRequest

    func `continue`(
        params: MSALNativeAuthSignUpContinueRequestProviderParams
    ) throws -> MSALNativeAuthSignUpContinueRequest
}

final class MSALNativeAuthSignUpRequestProvider: MSALNativeAuthRequestSignUpProviding {

    private let config: MSALNativeAuthConfiguration
    private let telemetryProvider: MSALNativeAuthTelemetryProviding

    init(config: MSALNativeAuthConfiguration, telemetryProvider: MSALNativeAuthTelemetryProviding) {
        self.config = config
        self.telemetryProvider = telemetryProvider
    }

    func start(
        parameters: MSALNativeAuthSignUpParameters,
        challengeTypes: [MSALNativeAuthChallengeType],
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpStartRequest {
        guard let attributes = try formatAttributes(parameters.attributes) else {
            throw MSALNativeAuthError.invalidAttributes
        }

        let params = MSALNativeAuthSignUpStartRequestParameters(
            config: config,
            username: parameters.email,
            password: parameters.password,
            attributes: attributes,
            challengeTypes: challengeTypes,
            context: context
        )

        let request = MSALNativeAuthSignUpStartRequest()

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpStart),
            context: context
        )

        try request.configure(
            params: params,
            requestSerializer: MSALNativeAuthUrlRequestSerializer(
                context: params.context,
                encoding: .wwwFormUrlEncoded
            ),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    func challenge(
        token: String,
        challengeTypes: [MSALNativeAuthChallengeType],
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignUpChallengeRequest {
        let params = MSALNativeAuthSignUpChallengeRequestParameters(
            config: config,
            signUpToken: token,
            challengeTypes: challengeTypes,
            context: context
        )

        let request = MSALNativeAuthSignUpChallengeRequest()

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpChallenge),
            context: context
        )

        try request.configure(
            params: params,
            requestSerializer: MSALNativeAuthUrlRequestSerializer(
                context: params.context,
                encoding: .wwwFormUrlEncoded
            ),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    func `continue`(
        params: MSALNativeAuthSignUpContinueRequestProviderParams
    ) throws -> MSALNativeAuthSignUpContinueRequest {
        let attributesFormatted = try params.attributes.map { try formatAttributes($0) } ?? nil

        let requestParameters = MSALNativeAuthSignUpContinueRequestParameters(
            config: config,
            grantType: params.grantType,
            signUpToken: params.signUpToken,
            password: params.password,
            oob: params.oob,
            attributes: attributesFormatted,
            context: params.context
        )

        let request = MSALNativeAuthSignUpContinueRequest()

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpContinue),
            context: params.context
        )

        try request.configure(
            params: requestParameters,
            requestSerializer: MSALNativeAuthUrlRequestSerializer(
                context: requestParameters.context,
                encoding: .wwwFormUrlEncoded
            ),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    private func formatAttributes(_ attributes: [String: Any]) throws -> String? {
        let data = try JSONSerialization.data(withJSONObject: attributes)
        return String(data: data, encoding: .utf8)?.msidWWWFormURLEncode()
    }
}
