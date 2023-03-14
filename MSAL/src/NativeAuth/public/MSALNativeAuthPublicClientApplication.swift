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

@objcMembers
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    private let controllerFactory: MSALNativeAuthRequestControllerBuildable
    private let inputValidator: MSALNativeAuthInputValidating

    public override init(configuration config: MSALPublicClientApplicationConfig) throws {
        guard let aadAuthority = config.authority as? MSALAADAuthority else {
            throw MSALNativeAuthError.invalidAuthority
        }

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: config.clientId,
            authority: aadAuthority
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        try super.init(configuration: config)
    }

    public init(clientId: String, rawTenant: String? = nil, redirectUri: String? = nil) throws {
        let aadAuthority = try MSALNativeAuthAuthorityProvider()
            .authority(rawTenant: rawTenant)

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: clientId,
            authority: aadAuthority,
            rawTenant: rawTenant
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        let configuration = MSALPublicClientApplicationConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            authority: aadAuthority
        )

        try super.init(configuration: configuration)
    }

    init(
        controllerFactory: MSALNativeAuthRequestControllerBuildable,
        inputValidator: MSALNativeAuthInputValidating
    ) {
        self.controllerFactory = controllerFactory
        self.inputValidator = inputValidator

        super.init()
    }

    // MARK: - Async/Await

    public func signUp(parameters: MSALNativeAuthSignUpParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signUp(parameters: parameters) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else if let result = result {
                    continuation.resume(returning: .success(result))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                }
            }
        }
    }

    public func signUp(parameters: MSALNativeAuthSignUpOTPParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signUp(otpParameters: parameters) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else if let result = result {
                    continuation.resume(returning: .success(result))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                }
            }
        }
    }

    public func signIn(parameters: MSALNativeAuthSignInParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signIn(parameters: parameters) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else if let result = result {
                    continuation.resume(returning: .success(result))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                    assert(false)
                }
            }
        }
    }

    public func signIn(otpParameters: MSALNativeAuthSignInOTPParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            signIn(otpParameters: otpParameters) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else if let result = result {
                    continuation.resume(returning: .success(result))
                } else {
                    assert(false)
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                }
            }
        }
    }

    public func resendCode(parameters: MSALNativeAuthResendCodeParameters) async -> ResendCodeResult {
        return await withCheckedContinuation { continuation in
            resendCode(parameters: parameters) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else if let result = result {
                    continuation.resume(returning: .success(result))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                    assert(false)
                }
            }
        }
    }

    public func verifyCode(parameters: MSALNativeAuthVerifyCodeParameters) async -> AuthResult {
        return await withCheckedContinuation { continuation in
            verifyCode(parameters: parameters) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else if let result = result {
                    continuation.resume(returning: .success(result))
                } else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.generalError))
                    assert(false)
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

    public func signUp(
        parameters: MSALNativeAuthSignUpParameters,
        completion: @escaping (_ response: MSALNativeAuthResponse?, _ error: Error?) -> Void
    ) {
        guard inputValidator.isEmailValid(parameters.email) else {
            completion(nil, MSALNativeAuthError.invalidInput)
            return
        }

        let controller = controllerFactory.makeSignUpController(
            with: MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        )

        controller.signUp(parameters: parameters, completion: completion)
    }

    public func signUp(
        otpParameters: MSALNativeAuthSignUpOTPParameters,
        completion: @escaping (_ response: MSALNativeAuthResponse?, _ error: Error?) -> Void
    ) {
        guard inputValidator.isEmailValid(otpParameters.email) else {
            completion(nil, MSALNativeAuthError.invalidInput)
            return
        }

        let controller = controllerFactory.makeSignUpOTPController(
            with: MSALNativeAuthRequestContext(correlationId: otpParameters.correlationId)
        )

        controller.signUp(parameters: otpParameters, completion: completion)
    }

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

    public func signIn(
        otpParameters: MSALNativeAuthSignInOTPParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    ) {
        guard inputValidator.isEmailValid(otpParameters.email) else {
            completion(nil, MSALNativeAuthError.invalidInput)
            return
        }

        let controller = controllerFactory.makeSignInOTPController(
            with: MSALNativeAuthRequestContext(correlationId: otpParameters.correlationId)
        )
        controller.signIn(parameters: otpParameters, completion: completion)
    }

    public func resendCode(
        parameters: MSALNativeAuthResendCodeParameters,
        completion: @escaping (_ credentialToken: String?, _ error: Error?) -> Void) {
            let resendCodeController = controllerFactory
                .makeResendCodeController(with: MSALNativeAuthRequestContext(correlationId: parameters.correlationId))
            resendCodeController.resendCode(parameters: parameters, completion: completion)
        }

    public func verifyCode(
        parameters: MSALNativeAuthVerifyCodeParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void) {
            let controller = controllerFactory.makeVerifyCodeController(
                with: MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
            )
            controller.verifyCode(parameters: parameters, completion: completion)
        }

    public func getUserAccount(completion: @escaping (MSALNativeAuthUserAccount, Error) -> Void) {

    }
}
