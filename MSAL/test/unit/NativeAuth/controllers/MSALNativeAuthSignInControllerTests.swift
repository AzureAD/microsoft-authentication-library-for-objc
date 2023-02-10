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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

final class MSALNativeAuthSignInControllerTests: XCTestCase {

    private var sut: MSALNativeAuthSignInController!
    private var requestProviderMock: MSALNativeAuthRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var responseHandlerMock: MSALNativeAuthResponseHandlerMock!
    private var authorityMock: MSALNativeAuthAuthority!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factoryMock: MSALNativeAuthResultFactoryMock!

    private var publicParametersStub: MSALNativeAuthSignInParameters {
        .init(email: DEFAULT_TEST_ID_TOKEN_USERNAME, password: "strong-password")
    }

    private var requestParametersStub: MSALNativeAuthSignInRequestParameters {
        .init(
            authority: MSALNativeAuthNetworkStubs.authority,
            clientId: DEFAULT_TEST_CLIENT_ID,
            endpoint: .signIn,
            context: contextMock,
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "strong-password",
            scope: "<scope-1>",
            grantType: .password
        )
    }

    private let tokenResponseDict: [String: Any] = [
        "token_type": "Bearer",
        "scope": "openid profile email",
        "expires_in": 4141,
        "ext_expires_in": 4141,
        "access_token": "accessToken",
        "refresh_token": "refreshToken",
        "id_token": "idToken"
    ]

    private var nativeAuthResponse: MSALNativeAuthResponse {
        .init(
            stage: .completed,
            credentialToken: nil,
            authentication: .init(
                accessToken: "<access_token>",
                idToken: "<id_token>",
                scopes: ["<scope_1>, <scope_2>"],
                expiresOn: Date(),
                tenantId: "myTenant"
            )
        )
    }

    override func setUpWithError() throws {
        requestProviderMock = .init()
        cacheAccessorMock = .init()
        responseHandlerMock = .init()
        authorityMock = MSALNativeAuthNetworkStubs.authority
        contextMock = .init()
        factoryMock = .init()

        sut = .init(
            configuration: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            cacheAccessor: cacheAccessorMock,
            responseHandler: responseHandlerMock,
            authority: authorityMock,
            context: contextMock,
            factory: factoryMock
        )
    }

    func test_when_creatingRequest_it_fails() throws {
        let expectation = expectation(description: "SignInController create request error")

        requestProviderMock.mockSignInRequestFunc(throwingError: ErrorMock.error)

        sut.signIn(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .invalidRequest)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_it_fails() throws {
        let baseUrl = URL(string: "https://www.contoso.com")!

        let parameters = ["p1": "v1"]

        let httpResponse = HTTPURLResponse(
            url: baseUrl,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        var urlRequest = URLRequest(url: baseUrl)
        urlRequest.httpMethod = "POST"

        let testUrlResponse = MSIDTestURLResponse.request(baseUrl, reponse: httpResponse)

        testUrlResponse?.setError(ErrorMock.error)

        testUrlResponse?.setUrlFormEncodedBody(parameters)
        testUrlResponse?.setResponseJSON([])
        MSIDTestURLSession.add(testUrlResponse)

        let request = try MSALNativeAuthSignInRequest(params: requestParametersStub)

        request.urlRequest = urlRequest
        request.parameters = parameters

        let expectation = expectation(description: "SignInController perform request error")

        requestProviderMock.mockSignInRequestFunc(result: request)

        sut.signIn(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? ErrorMock), .error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_it_fails_decode() throws {
        let request = try MSALNativeAuthSignInRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [])

        let expectation = expectation(description: "SignInController perform request error")

        requestProviderMock.mockSignInRequestFunc(result: request)

        sut.signIn(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .invalidResponse)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_verification_does_not_pass() throws {
        let request = try MSALNativeAuthSignInRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignInController perform request error")

        requestProviderMock.mockSignInRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        responseHandlerMock.mockHandleTokenFunc(throwingError: ErrorMock.error)

        sut.signIn(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .validationError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_succeeds_it_caches_the_response() throws {
        let request = try MSALNativeAuthSignInRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignInController perform request and cache response")

        requestProviderMock.mockSignInRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        responseHandlerMock.mockHandleTokenFunc(result: .init())

        sut.signIn(parameters: publicParametersStub) { [unowned self] response, error in
            XCTAssertNotNil(response)
            XCTAssertNil(error)
            XCTAssertTrue(self.cacheAccessorMock.saveTokenWasCalled)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_succeeds_it_returns_the_response() throws {
        let request = try MSALNativeAuthSignInRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignInController perform request success")

        requestProviderMock.mockSignInRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        responseHandlerMock.mockHandleTokenFunc(result: .init())

        sut.signIn(parameters: publicParametersStub) { response, error in
            XCTAssertNil(error)

            XCTAssertEqual(response?.authentication?.accessToken, "<access_token>")
            XCTAssertEqual(response?.authentication?.idToken, "<id_token>")
            XCTAssertEqual(response?.authentication?.scopes, ["<scope_1>, <scope_2>"])
            XCTAssertEqual(response?.authentication?.tenantId, "myTenant")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
