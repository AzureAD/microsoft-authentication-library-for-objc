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

protocol MSALNativeAuthSignUpRequestProviding {
    func start(parameters: MSALNativeAuthSignUpStartRequestProviderParameters) throws -> MSIDHttpRequest
    func challenge(token: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest
    func `continue`(parameters: MSALNativeAuthSignUpContinueRequestProviderParams) throws -> MSIDHttpRequest
}

final class MSALNativeAuthSignUpRequestProvider: MSALNativeAuthSignUpRequestProviding {

    private let requestConfigurator: MSALNativeAuthRequestConfigurator
    private let telemetryProvider: MSALNativeAuthTelemetryProviding

    init(requestConfigurator: MSALNativeAuthRequestConfigurator,
         telemetryProvider: MSALNativeAuthTelemetryProviding) {
        self.requestConfigurator = requestConfigurator
        self.telemetryProvider = telemetryProvider
    }

    func start(parameters: MSALNativeAuthSignUpStartRequestProviderParameters) throws -> MSIDHttpRequest {
        let formattedAttributes = try formatAttributes(parameters.attributes)
        let params = MSALNativeAuthSignUpStartRequestParameters(
            username: parameters.username,
            password: parameters.password,
            attributes: formattedAttributes,
            context: parameters.context
        )

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .signUp(.start(params)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    func challenge(token: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let params = MSALNativeAuthSignUpChallengeRequestParameters(
            continuationToken: token,
            context: context
        )

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .signUp(.challenge(params)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    func `continue`(parameters: MSALNativeAuthSignUpContinueRequestProviderParams) throws -> MSIDHttpRequest {
        let formattedAttributes = try formatAttributes(parameters.attributes)

        let params = MSALNativeAuthSignUpContinueRequestParameters(
            grantType: parameters.grantType,
            continuationToken: parameters.continuationToken,
            password: parameters.password,
            oobCode: parameters.oobCode,
            attributes: formattedAttributes,
            context: parameters.context
        )

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .signUp(.continue(params)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    private func formatAttributes(_ attributes: [String: Any]?) throws -> String? {
        guard let attributes = attributes else {
            return nil
        }
        guard JSONSerialization.isValidJSONObject(attributes) else {
            throw MSALNativeAuthInternalError.invalidAttributes
        }
        let data = try JSONSerialization.data(withJSONObject: attributes)
        return String(data: data, encoding: .utf8)
    }
}
