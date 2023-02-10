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

struct MSALNativeAuthNetworkStubs {

    static let tenantName = "test_tenant"

    static let requestProvider: MSALNativeAuthRequestProvider = .init(
        clientId: DEFAULT_TEST_CLIENT_ID,
        authority: authority
    )

    static var authority: MSALNativeAuthAuthority {
        try! .init(
            tenant: Self.tenantName,
            context: MSALNativeAuthRequestContext()
        )
    }
}

class MSALNativeAuthRequestContextMock: MSIDRequestContext {

    let id: UUID
    var mockTelemetryRequestId = ""

    init(correlationId: UUID = .init(uuidString: DEFAULT_TEST_UID)!) {
        self.id = correlationId
    }

    func correlationId() -> UUID {
        return id
    }

    func logComponent() -> String {
        return ""
    }

    func telemetryRequestId() -> String {
        return mockTelemetryRequestId
    }

    func appRequestMetadata() -> [AnyHashable: Any] {
        return [:]
    }
}

class MSALNativeAuthRequestProviderMock: MSALNativeAuthRequestProviding {

    private(set) var throwingError: Error?
    private(set) var signInRequestFuncResult: MSALNativeAuthSignInRequest?

    func mockSignInRequestFunc(throwingError: Error? = nil, result: MSALNativeAuthSignInRequest? = nil) {
        self.throwingError = throwingError
        self.signInRequestFuncResult = result
    }

    func signInRequest(parameters: MSALNativeAuthSignInParameters, context: MSIDRequestContext) throws -> MSALNativeAuthSignInRequest {
        if throwingError == nil && signInRequestFuncResult == nil {
            XCTFail("Both parameters are nil")
        }

        if let error = throwingError {
            throw error
        }

        if let signInRequestFuncResult = signInRequestFuncResult {
            return signInRequestFuncResult
        }

        // This will cause the tests to immediately stop execution. Make sure you're setting one param using `mockFunc()`
        return signInRequestFuncResult!
    }
}

class MSALNativeAuthResponseHandlerMock: MSALNativeAuthResponseHandling {

    private(set) var throwingError: Error?
    private(set) var handleTokenFuncResult: MSIDTokenResult?

    func mockHandleTokenFunc(throwingError: Error? = nil, result: MSIDTokenResult? = nil) {
        self.throwingError = throwingError
        self.handleTokenFuncResult = result
    }

    func handle(
        context: MSIDRequestContext,
        accountIdentifier: MSIDAccountIdentifier,
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        validateAccount: Bool
    ) throws -> MSIDTokenResult {
        if throwingError == nil && handleTokenFuncResult == nil {
            XCTFail("Both parameters are nil")
        }

        if let error = throwingError {
            throw error
        }

        if let handleFuncResult = handleTokenFuncResult {
            return handleFuncResult
        }

        // This will cause the tests to immediately stop execution. Make sure you're setting one param using `mockFunc()`
        return handleTokenFuncResult!
    }
}

class HttpModuleMockConfigurator {

    static func configure(request: MSIDHttpRequest, responseJson: Any) {
        let baseUrl = URL(string: "https://www.contoso.com")!

        let parameters = ["p1": "v1"]

        let httpResponse = HTTPURLResponse(
            url: baseUrl,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        var urlRequest = URLRequest(url: baseUrl)
        urlRequest.httpMethod = "POST"

        let testUrlResponse = MSIDTestURLResponse.request(baseUrl, reponse: httpResponse)
        testUrlResponse?.setUrlFormEncodedBody(parameters)
        testUrlResponse?.setResponseJSON(responseJson)
        MSIDTestURLSession.add(testUrlResponse)

        request.urlRequest = urlRequest
        request.parameters = parameters
    }
}
