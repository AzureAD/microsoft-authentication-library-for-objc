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

final class MSALNativeAuthTokenRequestHandlingTests: XCTestCase {

    private var sut: Sut!
    private var responseHandlerMock: MSALNativeAuthResponseHandlerMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!

    private class Sut: MSALNativeAuthBaseController, MSALNativeAuthTokenRequestHandling {

        init(responseHandler: MSALNativeAuthResponseHandling, cacheAccessor: MSALNativeAuthCacheInterface) {
            super.init(
                clientId: DEFAULT_TEST_CLIENT_ID,
                context: MSALNativeAuthRequestContextMock(),
                responseHandler: responseHandler,
                cacheAccessor: cacheAccessor
            )
        }
    }

    override func setUp() {
        super.setUp()

        responseHandlerMock = .init()
        cacheAccessorMock = .init()

        sut = .init(
            responseHandler: responseHandlerMock,
            cacheAccessor: cacheAccessorMock
        )
    }

    func test_whenPerformRequestFails_shouldReturnError() {
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

        let request = MSIDHttpRequest()

        request.urlRequest = urlRequest
        request.parameters = parameters

        let expectation = expectation(description: "Perform request request error")

        sut.performRequest(request) { result in
            switch result {
            case .failure(let error as ErrorMock):
                XCTAssertEqual(error, .error)
            default:
                XCTFail("Should not reach here")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenRequestDecodeFails_shouldReturnError() {
        let request = MSIDHttpRequest()

        HttpModuleMockConfigurator.configure(request: request, responseJson: [])

        let expectation = expectation(description: "Perform request request error")

        sut.performRequest(request) { result in
            switch result {
            case .failure(let error as MSALNativeAuthError):
                XCTAssertEqual(error, .invalidResponse)
            default:
                XCTFail("Should not reach here")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenPerformRequestSucceeds_shouldReturnResponse() {
        let request = MSIDHttpRequest()

        let tokenResponseDict: [String: Any] = [
            "token_type": "Bearer",
            "scope": "openid profile email",
            "expires_in": 4141,
            "ext_expires_in": 4141,
            "access_token": "accessToken",
            "refresh_token": "refreshToken",
            "id_token": "idToken"
        ]

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "Perform request request error")

        sut.performRequest(request) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.accessToken, "accessToken")
                XCTAssertEqual(response.idToken, "idToken")
                XCTAssertEqual(response.scope, "openid profile email")
                XCTAssertEqual(response.expiresIn, 4141)
                XCTAssertEqual(response.extendedExpiresIn, 4141)
                XCTAssertEqual(response.tokenType, "Bearer")
            default:
                XCTFail("Should not reach here")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_handleResponse_callsResponseHandler() {
        responseHandlerMock.mockHandleTokenFunc(result: .init())

        XCTAssertNotNil(
            sut.handleResponse(.init(), msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration)
        )
    }

    func test_cacheTokenResponse_callsCacheAccessor() {
        XCTAssertFalse(cacheAccessorMock.saveTokenWasCalled)

        sut.cacheTokenResponse(.init(), msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration)

        XCTAssertTrue(cacheAccessorMock.saveTokenWasCalled)
    }
}
