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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

@objc
public final class MSALNativeAuthPublicClientApplication: NSObject {

    /**
     Initializes a new application.

     - Parameters:
        - configuration: `MSALCiamPublicClientApplicationConfig` . CIAM's sdk configuration,
            which contains authority, tenant and clientId.
     */

    private let controllerFactory: MSALNativeAuthRequestControllerBuildable
    private let configuration: MSALNativeAuthPublicClientApplicationConfig
    private let inputValidator: MSALNativeAuthInputValidating

    @objc
    public convenience init(configuration: MSALNativeAuthPublicClientApplicationConfig) {

        do {
            let authority = try MSALNativeAuthAuthority(
                tenant: configuration.tenantName,
                context: MSALNativeAuthRequestContext()
            )

            let requestProvider = MSALNativeAuthRequestProvider(
                clientId: configuration.clientId,
                authority: authority
            )

            let factory = MSALNativeAuthRequestControllerFactory(
                requestProvider: requestProvider,
                cacheGateway: MSALNativeAuthCacheAccessor(),
                responseHandler: MSALNativeAuthResponseHandler(),
                configuration: configuration,
                authority: authority
            )

            self.init(
                configuration: configuration,
                controllerFactory: factory,
                inputValidator: MSALNativeAuthInputValidator()
            )
        } catch {
            MSALLogger.log(
                level: .error,
                context: MSALNativeAuthRequestContext(),
                format: "Error building MSALNativeAuthAuthority"
            )

            self.init(configuration: configuration)
        }
    }

    init(
        configuration: MSALNativeAuthPublicClientApplicationConfig,
        controllerFactory: MSALNativeAuthRequestControllerBuildable,
        inputValidator: MSALNativeAuthInputValidating
    ) {
        self.configuration = configuration
        self.controllerFactory = controllerFactory
        self.inputValidator = inputValidator
    }

    // MARK: - Async/Await

    public func signUp(
        parameters: MSALNativeAuthSignUpParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signUp(parameters: parameters) { _, _ in
                continuation.resume(returning:
                        .success(.init(stage: .completed, credentialToken: nil, authentication: nil)))
            }
        }
    }

    public func signUp(parameters: MSALNativeAuthSignUpOTPParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signUp(otpParameters: parameters) { _, _ in
                continuation.resume(returning:
                        .success(.init(stage: .completed, credentialToken: nil, authentication: nil)))
            }
        }
    }

    public func signIn(parameters: MSALNativeAuthSignInParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signIn(parameters: parameters) { result, error in
                if let result = result {
                    continuation.resume(returning: .success(result))
                } else if let error = error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                }
            }
        }
    }

    public func signIn(parameters: MSALNativeAuthSignInOTPParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signIn(otpParameters: parameters) { _, _ in
                continuation.resume(returning:
                        .success(.init(stage: .completed, credentialToken: nil, authentication: nil)))
            }
        }
    }

    public func verifyCode(parameters: MSALNativeAuthVerifyCodeParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            verifyCode(parameters: parameters) { _, _ in
                continuation.resume(returning:
                        .success(.init(stage: .completed, credentialToken: nil, authentication: nil)))
            }
        }
    }

    public func resendCode(parameters: MSALNativeAuthResendCodeParameters) async -> ResendCodeResult {
        return await withCheckedContinuation { continuation in
            resendCode(parameters: parameters) { result, error in
                if let result = result {
                    continuation.resume(returning: .success(result))
                } else if let error = error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                }
            }
        }
    }

    public func getUserAccount() async -> UserAccountResult {
        return await withCheckedContinuation { continuation in
            getUserAccount { _, _ in
                continuation.resume(returning: .success(.init(email: "", attributes: [:])))
            }
        }
    }

    // MARK: - Closures

    @objc
    public func signUp(
        parameters: MSALNativeAuthSignUpParameters,
        completion: @escaping (_ response: MSALNativeAuthResponse?, _ error: Error?) -> Void) {
            guard inputValidator.isEmailValid(parameters.email) else {
                completion(nil, MSALNativeAuthError.invalidInput)
                return
            }
            let signUpController = controllerFactory.makeSignUpController()
            signUpController.signUp(parameters: parameters) { result in
                switch result {
                case .success(let response):
                    completion(response, nil)
                case .failure(let error):
                    completion(nil, error)
                }
            }
    }

    @objc
    public func signUp(otpParameters: MSALNativeAuthSignUpOTPParameters,
                       completion: @escaping (_ response: MSALNativeAuthResponse, _ error: Error) -> Void) {

    }

    @objc
    public func signIn(
        parameters: MSALNativeAuthSignInParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    ) {
        guard inputValidator.isEmailValid(parameters.email) else {
            completion(nil, MSALNativeAuthError.invalidInput)
            return
        }

        let controller = controllerFactory.makeSignInController(
            with: MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        )
        controller.signIn(parameters: parameters, completion: completion)
    }

    @objc
    public func signIn(
        otpParameters: MSALNativeAuthSignInOTPParameters,
        completion: @escaping (MSALNativeAuthResponse, Error) -> Void) {

    }

    @objc
    public func verifyCode(
        parameters: MSALNativeAuthVerifyCodeParameters,
        completion: @escaping (MSALNativeAuthResponse, Error) -> Void) {

    }

    @objc
    public func resendCode(
        parameters: MSALNativeAuthResendCodeParameters,
        completion: @escaping (_ credentialToken: String?, _ error: Error?) -> Void) {
            let resendCodeController = controllerFactory
                .makeResendCodeController(with: MSALNativeAuthRequestContext(correlationId: parameters.correlationId))
            resendCodeController.resendCode(parameters: parameters, completion: completion)
        }

    @objc
    public func getUserAccount(completion: @escaping (MSALNativeAuthUserAccount, Error) -> Void) {

    }
}
