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

class MSALNativeAuthSignInInitiateIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private var sut: MSALNativeAuthRequestProvider!
    let telemetryProvider = MSALNativeAuthTelemetryProvider()

    override func setUpWithError() throws {
        sut = MSALNativeAuthRequestProvider(config: config)
        try super.setUpWithError()
    }

    func test_createSendAndRecieveRequest_correctParameters() {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthSignInInitiateRequestParameters(config: config,
                                                                       context: context,
                                                                       username: "test@test.com",
                                                                       challengeType: .otp)

        let request = try! sut.signInInitiateRequest(parameters: parameters,
                                                    context: context)
        let expectation = XCTestExpectation()
        request.send { result, error in
            print(result)
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 5)
    }
}
