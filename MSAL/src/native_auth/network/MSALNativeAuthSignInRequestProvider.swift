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

protocol MSALNativeAuthRequestSignInProviding {
    func signInInitiateRequest(
        context: MSIDRequestContext,
        username: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType]
    ) throws -> MSALNativeAuthSignInInitiateRequest

    func signInChallengeRequest(
        credentialToken: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType]?,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInChallengeRequest

    func signInTokenRequest(
        parameters: MSALNativeAuthSignInTokenRequestProviderParams
    ) throws -> MSALNativeAuthSignInTokenRequest
}

final class MSALNativeAuthSignInRequestProvider: MSALNativeAuthRequestSignInProviding {

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

    // MARK: - SignIn Initiate

    func signInInitiateRequest(
        context: MSIDRequestContext,
        username: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType]
    ) throws -> MSALNativeAuthSignInInitiateRequest {
        let parameters = MSALNativeAuthSignInInitiateRequestParameters(config: config, context: context, username: username, challengeTypes: challengeTypes)
        
        let request = try MSALNativeAuthSignInInitiateRequest(params: parameters)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInInitiate),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: parameters.context,
                                                                  encoding: .wwwFormUrlEncoded),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - SignIn Challenge

    func signInChallengeRequest(
        credentialToken: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType]?,
        context: MSIDRequestContext
    ) throws -> MSALNativeAuthSignInChallengeRequest {
        let parameters = MSALNativeAuthSignInChallengeRequestParameters(config: config, context: context, credentialToken: credentialToken, challengeTypes: challengeTypes)
        let request = try MSALNativeAuthSignInChallengeRequest(params: parameters)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInChallenge),
            context: context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: parameters.context,
                                                                  encoding: .wwwFormUrlEncoded),
            serverTelemetry: serverTelemetry
        )

        return request
    }

    // MARK: - SignIn Token

    func signInTokenRequest(
        parameters: MSALNativeAuthSignInTokenRequestProviderParams
    ) throws -> MSALNativeAuthSignInTokenRequest {
        let parameters = MSALNativeAuthSignInTokenRequestParameters(
            config: config,
            context: parameters.context,
            username: parameters.username,
            credentialToken: parameters.credentialToken,
            signInSLT: parameters.signInSLT,
            grantType: parameters.grantType,
            challengeTypes: parameters.challengeTypes,
            scope: formatScope(parameters.scopes),
            password: parameters.password,
            oobCode: parameters.oobCode)
        let request = try MSALNativeAuthSignInTokenRequest(params: parameters)

        let serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInChallenge),
            context: parameters.context
        )

        request.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: parameters.context,
                                                                  encoding: .wwwFormUrlEncoded),
            serverTelemetry: serverTelemetry
        )

        return request
    }
    
    private func formatScope(_ scope: [String]) -> String {
        return scope.joined(separator: ",")
    }
}
