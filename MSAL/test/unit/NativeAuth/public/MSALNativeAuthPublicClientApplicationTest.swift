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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

final class MSALNativeAuthPublicClientApplicationTest: XCTestCase {
    
    private static let credentialToken = "token"
    private static let authenticationResult = MSALNativeAuthenticationResult(accessToken: "access", idToken: "id", scopes: ["user.read"], expiresOn: Date(), tenantId: "tenant")
    
    private class MSALNativeAuthInputValidatorStub: MSALNativeAuthInputValidating {
        var expectedResult = false
        
        func isEmailValid(_ email: String) -> Bool {
            return expectedResult
        }
    }

    private class MSALNativeAuthRequestControllerFactoryCustomSuccess: MSALNativeAuthRequestControllerFactoryFail {
        private class MSALNativeAuthSignUpControllerCustomSuccess: MSALNativeAuthBaseController, MSALNativeAuthSignUpControlling {
            func signUp(parameters: MSAL.MSALNativeAuthSignUpParameters, completion: @escaping (MSAL.MSALNativeAuthResponse?, Error?) -> Void) {
                completion(MSALNativeAuthResponse(stage: .completed, credentialToken: credentialToken, authentication: authenticationResult), nil)
            }
        }

        private class MSALNativeAuthSignInControllerCustomSuccess: MSALNativeAuthBaseController, MSALNativeAuthSignInControlling {
            func signIn(parameters: MSALNativeAuthSignInParameters, completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void) {
                completion(MSALNativeAuthResponse(stage: .completed, credentialToken: credentialToken, authentication: authenticationResult), nil)
            }
        }

        private class MSALNativeAuthSignInOTPControllerCustomSuccess: MSALNativeAuthBaseController, MSALNativeAuthSignInOTPControlling {
            func signIn(parameters: MSALNativeAuthSignInOTPParameters, completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void) {
                completion(MSALNativeAuthResponse(stage: .verificationRequired, credentialToken: credentialToken, authentication: nil), nil)
            }
        }

        private class MSALNativeAuthResendCodeControllerCustomSuccess: MSALNativeAuthResendCodeControlling {
            func resendCode(parameters: MSAL.MSALNativeAuthResendCodeParameters, completion: @escaping (String?, Error?) -> Void) {
                completion(credentialToken, nil)            }
        }

        private class MSALNativeAuthVerifyCodeControllerCustomSuccess: MSALNativeAuthBaseController, MSALNativeAuthVerifyCodeControlling {
            func verifyCode(parameters: MSAL.MSALNativeAuthVerifyCodeParameters, completion: @escaping (MSAL.MSALNativeAuthResponse?, Error?) -> Void) {
                completion(MSALNativeAuthResponse(stage: .completed, credentialToken: credentialToken, authentication: authenticationResult), nil)
            }
        }

        override func makeSignUpController(with context: MSIDRequestContext) -> MSALNativeAuthSignUpControlling {
            return MSALNativeAuthSignUpControllerCustomSuccess(
                configuration: MSALNativeAuthConfigStubs.configuration,
                context: MSALNativeAuthRequestContextMock(),
                responseHandler: MSALNativeAuthResponseHandlerMock(),
                cacheAccessor: MSALNativeAuthCacheAccessorMock()
            )
        }

        override func makeSignInController(with context: MSIDRequestContext) -> MSALNativeAuthSignInControlling {
            return MSALNativeAuthSignInControllerCustomSuccess(
                configuration: MSALNativeAuthConfigStubs.configuration,
                context: MSALNativeAuthRequestContextMock(),
                responseHandler: MSALNativeAuthResponseHandlerMock(),
                cacheAccessor: MSALNativeAuthCacheAccessorMock()
            )
        }

        override func makeSignInOTPController(with context: MSIDRequestContext) -> MSALNativeAuthSignInOTPControlling {
            return MSALNativeAuthSignInOTPControllerCustomSuccess(
                configuration: MSALNativeAuthConfigStubs.configuration,
                context: MSALNativeAuthRequestContextMock(),
                responseHandler: MSALNativeAuthResponseHandlerMock(),
                cacheAccessor: MSALNativeAuthCacheAccessorMock()
            )
        }

        override func makeResendCodeController(with context: MSIDRequestContext) -> MSALNativeAuthResendCodeControlling {
            return MSALNativeAuthResendCodeControllerCustomSuccess()
        }

        override func makeVerifyCodeController(with context: MSIDRequestContext) -> MSALNativeAuthVerifyCodeControlling {
            return MSALNativeAuthVerifyCodeControllerCustomSuccess(
                configuration: MSALNativeAuthConfigStubs.configuration,
                context: MSALNativeAuthRequestContextMock(),
                responseHandler: MSALNativeAuthResponseHandlerMock(),
                cacheAccessor: MSALNativeAuthCacheAccessorMock()
            )
        }
    }
    
    func testSignUp_whenValidationFails_shouldReturnAnError() {
        let expectation = XCTestExpectation()
        let config = MSALNativeAuthPublicClientApplicationConfig(clientId: "", authority: URL(string: "www.contoso.com")!, tenantName: "")
        let application = MSALNativeAuthPublicClientApplication(configuration: config, controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidatorStub())
        application.signUp(parameters: MSALNativeAuthSignUpParameters(email: "", password: "")) { response, error in
            XCTAssertEqual(error?.localizedDescription, MSALNativeAuthError.invalidInput.localizedDescription)
            XCTAssertNil(response)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testSignUp_whenControllerReturnAResult_ApplicationShouldMatchResult() {
        let expectation = XCTestExpectation()
        let config = MSALNativeAuthPublicClientApplicationConfig(clientId: "", authority: URL(string: "www.contoso.com")!, tenantName: "")
        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true
        let application = MSALNativeAuthPublicClientApplication(configuration: config, controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(), inputValidator: validator)
        application.signUp(parameters: MSALNativeAuthSignUpParameters(email: "", password: "")) { response, error in
            XCTAssertEqual(response?.stage, .completed)
            XCTAssertEqual(response?.authentication, MSALNativeAuthPublicClientApplicationTest.authenticationResult)
            XCTAssertEqual(response?.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_signUp_AsyncAwait_whenControllerReturnsAResult_ApplicationShouldMatchResult() async {
        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        let result = await application.signUp(parameters: .init(email: "", password: ""))

        switch result {
        case .success(let response):
            XCTAssertEqual(response.stage, .completed)
            XCTAssertEqual(response.authentication, MSALNativeAuthPublicClientApplicationTest.authenticationResult)
            XCTAssertEqual(response.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
        case .failure(let error):
            XCTFail("Should not reach here: \(error)")
        }
    }

    func testSignIn_whenValidationFails_shouldReturnAnError() {
        let expectation = XCTestExpectation()
        let config = MSALNativeAuthPublicClientApplicationConfig(clientId: "", authority: URL(string: "www.contoso.com")!, tenantName: "")
        let application = MSALNativeAuthPublicClientApplication(configuration: config, controllerFactory: MSALNativeAuthRequestControllerFactoryFail(), inputValidator: MSALNativeAuthInputValidatorStub())
        application.signIn(parameters: MSALNativeAuthSignInParameters(email: "", password: "")) { response, error in
            XCTAssertEqual(error?.localizedDescription, MSALNativeAuthError.invalidInput.localizedDescription)
            XCTAssertNil(response)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_signIn_whenControllerReturnsAResult_ApplicationShouldMatchResult() {
        let expectation = XCTestExpectation()

        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        application.signIn(parameters: .init(email: "", password: "")) { response, error in
            XCTAssertEqual(response?.stage, .completed)
            XCTAssertEqual(response?.authentication, MSALNativeAuthPublicClientApplicationTest.authenticationResult)
            XCTAssertEqual(response?.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_signIn_AsyncAwait_whenControllerReturnsAResult_ApplicationShouldMatchResult() async {
        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        let result = await application.signIn(parameters: .init(email: "", password: ""))

        switch result {
        case .success(let response):
            XCTAssertEqual(response.stage, .completed)
            XCTAssertEqual(response.authentication, MSALNativeAuthPublicClientApplicationTest.authenticationResult)
            XCTAssertEqual(response.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
        case .failure(let error):
            XCTFail("Should not reach here: \(error)")
        }
    }

    func test_signInOTP_whenControllerReturnsAResult_ApplicationShouldMatchResult() {
        let expectation = XCTestExpectation()

        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        application.signIn(otpParameters: .init(email: "")) { response, error in
            XCTAssertEqual(response?.stage, .verificationRequired)
            XCTAssertNil(response?.authentication)
            XCTAssertEqual(response?.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_signInOTP_AsyncAwait_whenControllerReturnsAResult_ApplicationShouldMatchResult() async {
        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        let result = await application.signIn(otpParameters: .init(email: ""))

        switch result {
        case .success(let response):
            XCTAssertEqual(response.stage, .verificationRequired)
            XCTAssertNil(response.authentication)
            XCTAssertEqual(response.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
        case .failure(let error):
            XCTFail("Should not reach here: \(error)")
        }
    }

    func test_resendCode_whenControllerReturnsAResult_ApplicationShouldMatchResult() {
        let expectation = XCTestExpectation()

        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        application.resendCode(parameters: .init(credentialToken: "")) { response, error in
            XCTAssertEqual(response, MSALNativeAuthPublicClientApplicationTest.credentialToken)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_resendCode_AsyncAwait_whenControllerReturnsAResult_ApplicationShouldMatchResult() async {
        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        let result = await application.resendCode(parameters: .init(credentialToken: ""))

        switch result {
        case .success(let response):
            XCTAssertEqual(response, MSALNativeAuthPublicClientApplicationTest.credentialToken)
        case .failure(let error):
            XCTFail("Should not reach here: \(error)")
        }
    }

    func test_verifyCode_whenControllerReturnsAResult_ApplicationShouldMatchResult() {
        let expectation = XCTestExpectation()

        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        application.verifyCode(parameters: .init(credentialToken: "", otp: "")) { response, error in
            XCTAssertEqual(response?.stage, .completed)
            XCTAssertEqual(response?.authentication, MSALNativeAuthPublicClientApplicationTest.authenticationResult)
            XCTAssertEqual(response?.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_verifyCode_AsyncAwait_whenControllerReturnsAResult_ApplicationShouldMatchResult() async {
        let validator = MSALNativeAuthInputValidatorStub()
        validator.expectedResult = true

        let application = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthConfigStubs.configuration,
            controllerFactory: MSALNativeAuthRequestControllerFactoryCustomSuccess(),
            inputValidator: validator
        )

        let result = await application.verifyCode(parameters: .init(credentialToken: "", otp:""))

        switch result {
        case .success(let response):
            XCTAssertEqual(response.stage, .completed)
            XCTAssertEqual(response.authentication, MSALNativeAuthPublicClientApplicationTest.authenticationResult)
            XCTAssertEqual(response.credentialToken, MSALNativeAuthPublicClientApplicationTest.credentialToken)
        case .failure(let error):
            XCTFail("Should not reach here: \(error)")
        }
    }
}
