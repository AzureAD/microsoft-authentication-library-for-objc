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
    
    private class MSALNativeAuthRequestControllerFactoryCustomSuccess: MSALNativeAuthRequestControllerFactoryFail {
        private class MSALNativeAuthSignUpControllerCustomSuccess: MSALNativeAuthSignUpControlling {
            func signUp(parameters: MSAL.MSALNativeAuthSignUpParameters, completion: @escaping (Result<MSAL.MSALNativeAuthResponse, Error>) -> Void) {
                completion(.success(MSALNativeAuthResponse(stage: .completed, credentialToken: credentialToken, authentication: authenticationResult)))
            }
        }

        private class MSALNativeAuthSignInControllerCustomSuccess: MSALNativeAuthSignInControlling {
            func signIn(parameters: MSALNativeAuthSignInParameters, completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void) {
                completion(MSALNativeAuthResponse(stage: .completed, credentialToken: credentialToken, authentication: authenticationResult), nil)
            }
        }

        override func makeSignUpController() -> MSALNativeAuthSignUpControlling {
            return MSALNativeAuthSignUpControllerCustomSuccess()
        }

        override func makeSignInController(with context: MSIDRequestContext) -> MSALNativeAuthSignInControlling {
            return MSALNativeAuthSignInControllerCustomSuccess()
        }
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
}
