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

// swiftlint:disable:next type_name
protocol MSALNativeAuthRequestResetPasswordProviding {
    func start(
        parameters: MSALNativeAuthResetPasswordStartRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest

    func challenge(
        parameters: MSALNativeAuthResetPasswordChallengeRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest

    func `continue`(
        parameters: MSALNativeAuthResetPasswordContinueRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest

    func submit(
        parameters: MSALNativeAuthResetPasswordSubmitRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest

    func pollCompletion(
        parameters: MSALNativeAuthResetPasswordPollCompletionRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest
}

// swiftlint:disable:next type_name
final class MSALNativeAuthResetPasswordRequestProvider: MSALNativeAuthRequestResetPasswordProviding {

    // MARK: - Variables

    private let config: MSALNativeAuthConfiguration
    private let requestConfigurator: MSALNativeAuthRequestConfigurator
    private let telemetryProvider: MSALNativeAuthTelemetryProviding

    // MARK: - Init

    init(
        config: MSALNativeAuthConfiguration,
        requestConfigurator: MSALNativeAuthRequestConfigurator,
        telemetryProvider: MSALNativeAuthTelemetryProviding = MSALNativeAuthTelemetryProvider()
    ) {
        self.config = config
        self.requestConfigurator = requestConfigurator
        self.telemetryProvider = telemetryProvider
    }

    // MARK: - Reset Password Start

    func start(
        parameters: MSALNativeAuthResetPasswordStartRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .resetPassword(.start(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    // MARK: - Reset Password Challenge

    func challenge(
        parameters: MSALNativeAuthResetPasswordChallengeRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .resetPassword(.challenge(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    // MARK: - Reset Password Continue

    func `continue`(
        parameters: MSALNativeAuthResetPasswordContinueRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .resetPassword(.continue(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    // MARK: - Reset Password Submit

    func submit(
        parameters: MSALNativeAuthResetPasswordSubmitRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .resetPassword(.submit(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    // MARK: - Reset Password Poll Completion

    func pollCompletion(
        parameters: MSALNativeAuthResetPasswordPollCompletionRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .resetPassword(.pollCompletion(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }
}
