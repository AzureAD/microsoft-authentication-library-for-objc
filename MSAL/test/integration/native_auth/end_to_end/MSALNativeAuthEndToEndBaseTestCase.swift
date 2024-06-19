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

import XCTest
import MSAL

class MSALNativeAuthEndToEndBaseTestCase: XCTestCase {
    let mockAPIHandler = MockAPIHandler()
    let correlationId = UUID()
    var defaultTimeout: TimeInterval = 5

    var sut: MSALNativeAuthPublicClientApplication!
    var usingMockAPI = false

    class Configuration: NSObject {
        static let clientId = ProcessInfo.processInfo.environment["clientId"] ?? "<clientId not set>"
        static let authorityURLString = ProcessInfo.processInfo.environment["authorityURL"] ?? "<authorityURL not set>"
    }

    func mockResponse(_ response: MockAPIResponse, endpoint: MockAPIEndpoint) async throws {
        try await mockAPIHandler.addResponse(
            endpoint: endpoint,
            correlationId: correlationId,
            responses: [response]
        )
    }

    override func tearDown() {
        try? mockAPIHandler.clearQueues(correlationId: correlationId)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let useMockAPIBooleanString = ProcessInfo.processInfo.environment["useMockAPI"] ?? "false"
        usingMockAPI = Bool(useMockAPIBooleanString) ?? false
        
        // mock API URL needs to contains a tenant
        guard let authorityURL = URL(string: Configuration.authorityURLString + (usingMockAPI ? "/testTenant" : "")), let authority = try? MSALCIAMAuthority(url: authorityURL) else {
            XCTFail("AuthorityURL not set or invalid")
            return
        }

        sut = try MSALNativeAuthPublicClientApplication(
            configuration: MSALPublicClientApplicationConfig(
                clientId: Configuration.clientId,
                redirectUri: nil,
                authority: authority
            ),
            challengeTypes: [.OOB, .password]
        )

        if usingMockAPI {
            print("🤖🤖🤖 Using mock API: \(Configuration.authorityURLString)")
        } else {
            print("👩‍💻👩‍💻👩‍💻 Using test tenant: \(Configuration.authorityURLString)")
        }
    }
}
