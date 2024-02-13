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
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthRequestableTests: XCTestCase {
    
    var request: MSALNativeAuthResetPasswordStartRequestParameters! = nil

    override func setUpWithError() throws {
        let context = MSALNativeAuthRequestContext(correlationId: UUID(uuidString: DEFAULT_TEST_UID)!)
        
        request = MSALNativeAuthResetPasswordStartRequestParameters(context: context, username: DEFAULT_TEST_ID_TOKEN_USERNAME)
    }
    
    func test_whenSliceConfigIsUsed_CorrectURLIsGenerated() throws {
        let sliceDc = "TEST-SLICE-IDENTIFIER"
        
        guard let authorityUrl = URL(string: DEFAULT_TEST_AUTHORITY) else {
            XCTFail()
            return
        }
        
        let authority = try MSALCIAMAuthority(url: authorityUrl)
        var config = try MSALNativeAuthConfiguration(clientId: DEFAULT_TEST_CLIENT_ID,
                                                      authority: authority,
                                                      challengeTypes: [.redirect])
        
        config.sliceConfig = MSALSliceConfig(slice: nil, dc: sliceDc)
        let url = try request.makeEndpointUrl(config: config)
        
        let expectedUrlString = config.authority.url.absoluteString + request.endpoint.rawValue + "?dc=\(sliceDc)"
        XCTAssertEqual(url.absoluteString, expectedUrlString)
    }
    
    func test_whenSliceConfigIsNotUsed_CorrectURLIsGenerated() throws {
        guard let authorityUrl = URL(string: DEFAULT_TEST_AUTHORITY) else {
            XCTFail()
            return
        }
        
        let authority = try MSALCIAMAuthority(url: authorityUrl)
        let config = try MSALNativeAuthConfiguration(clientId: DEFAULT_TEST_CLIENT_ID,
                                                      authority: authority,
                                                      challengeTypes: [.redirect])
        
        let url = try request.makeEndpointUrl(config: config)
        
        let expectedUrlString = config.authority.url.absoluteString + request.endpoint.rawValue
        XCTAssertEqual(url.absoluteString, expectedUrlString)
    }
}
