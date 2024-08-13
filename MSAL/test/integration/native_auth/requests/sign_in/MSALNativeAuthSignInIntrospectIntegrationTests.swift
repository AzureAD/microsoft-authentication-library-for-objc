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

class MSALNativeAuthSignInIntrospectIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthSignInIntrospectResponseError
    private var provider: MSALNativeAuthSignInRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignInRequestProvider(requestConfigurator: MSALNativeAuthRequestConfigurator(config: config))

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.introspect(
            parameters: .init(
                context: context,
                continuationToken: "Test Credential Token"
            ),
            context: context
        )
    }
    
    func test_succeedRequest_challengeTypeRedirect() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signInIntrospect)
        let response: MSALNativeAuthSignInIntrospectResponse? = try await performTestSucceed()

        XCTAssertNil(response?.continuationToken)
        XCTAssertEqual(response?.challengeType, .redirect)
    }

    func test_succeedRequest_successfulResult() async throws {
        try await mockResponse(.signInIntrospectSuccess, endpoint: .signInIntrospect)
        let response: MSALNativeAuthSignInIntrospectResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.continuationToken)
        guard let firstMethod = response?.methods?.first else {
            return XCTFail("No authentication method returned")
        }
        XCTAssertEqual(firstMethod.id, "F37D8C55-BE83-449F-8F99-131F6553871D")
        XCTAssertEqual(firstMethod.challengeChannel, .email)
        XCTAssertEqual(firstMethod.challengeType, .oob)
        XCTAssertEqual(firstMethod.loginHint, "**o*@c****so.com")
    }

    func test_failRequest_invalidRequest() async throws {
        try await perform_testFail(
            endpoint: .signInIntrospect,
            response: .invalidToken,
            expectedError: Error(error: .invalidRequest, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }
}
