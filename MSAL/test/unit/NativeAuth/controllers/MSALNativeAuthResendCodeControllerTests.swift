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

final class MSALNativeAuthResendCodeControllerTests: XCTestCase {

    private var sut: MSALNativeAuthResendCodeController!
    private var requestProviderMock: MSALNativeAuthRequestProviderMock!
    private var responseHandlerMock: MSALNativeAuthResponseHandlerMock!
    private var authorityMock: MSALNativeAuthAuthority!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factoryMock: MSALNativeAuthResultFactoryMock!

    private var publicParametersStub: MSALNativeAuthResendCodeParameters {
        .init(credentialToken:"Test Credential Token")
    }

    private var requestParametersStub: MSALNativeAuthResendCodeRequestParameters {
        .init(
            authority: MSALNativeAuthNetworkStubs.authority,
            clientId: DEFAULT_TEST_CLIENT_ID,
            endpoint: .resendCode,
            context: contextMock,
            credentialToken: "Test Credential Token"
        )
    }

    private let resendCodeResponse = MSALNativeAuthResendCodeRequestResponse(credentialToken: "Test Credential Token")

    private let resendCodeResponseDict: [String: Any] = [
        "flowToken": "Test Credential Token"
    ]

    private let emptyResendCodeResponseDict: [String: Any] = [
        "flowToken": ""
    ]

    override func setUpWithError() throws {
        requestProviderMock = .init()
        responseHandlerMock = .init()
        authorityMock = MSALNativeAuthNetworkStubs.authority
        contextMock = .init()
        factoryMock = .init()

        sut = .init(
            configuration: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseHandler: responseHandlerMock,
            authority: authorityMock,
            context: contextMock,
            factory: factoryMock
        )
    }

    func test_when_creatingRequest_it_fails() throws {
        let expectation = expectation(description: "ResendCodeController create request error")

        requestProviderMock.mockResendCodeRequestFunc(throwingError: ErrorMock.error)

        sut.resendCode(parameters: publicParametersStub) { response, error in
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

        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        request.urlRequest = urlRequest
        request.parameters = parameters

        let expectation = expectation(description: "ResendCodeController perform request error")

        requestProviderMock.mockResendCodeRequestFunc(result: request)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? ErrorMock), .error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_it_fails_decode() throws {
        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [])

        let expectation = expectation(description: "ResendCodeController perform request error")

        requestProviderMock.mockResendCodeRequestFunc(result: request)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .invalidResponse)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_verification_does_not_pass() throws {
        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: emptyResendCodeResponseDict)

        request.responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResendCodeRequestResponse>()
        
        let expectation = expectation(description: "ResendCodeController perform request error")

        requestProviderMock.mockResendCodeRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        responseHandlerMock.mockHandleResendCodeFunc(throwingError: ErrorMock.error)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .validationError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_when_performRequest_succeeds_it_returns_the_response() throws {
        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: resendCodeResponseDict)

        request.responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResendCodeRequestResponse>()

        let expectation = expectation(description: "ResendCodeController perform request success")

        requestProviderMock.mockResendCodeRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        responseHandlerMock.mockHandleResendCodeFunc(result: true)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertEqual(response, "Test Credential Token")
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
