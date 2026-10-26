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

class MSALNativeAuthCIAMTokenResponseTests: XCTestCase {
    
    func test_redirectResponse_isParsedCorrectly() {
        let redirectReason = "reason"
        var jsonDictionary = [String: String]()
        jsonDictionary["challenge_type"] = "redirect"
        jsonDictionary["redirect_reason"] = redirectReason
        let tokenResponse = try? MSALNativeAuthCIAMTokenResponse(jsonDictionary: jsonDictionary)
        XCTAssertEqual(tokenResponse?.challengeType, .redirect)
        XCTAssertEqual(tokenResponse?.redirectReason, redirectReason)
        XCTAssertNil(tokenResponse?.accessToken)
    }
    
    func test_invalidChallengeType_isParsedCorrectly() {
        let redirectReason = "reason"
        var jsonDictionary = [String: String]()
        jsonDictionary["challenge_type"] = "contoso"
        jsonDictionary["redirect_reason"] = redirectReason
        let tokenResponse = try? MSALNativeAuthCIAMTokenResponse(jsonDictionary: jsonDictionary)
        XCTAssertNil(tokenResponse?.challengeType)
        XCTAssertEqual(tokenResponse?.redirectReason, redirectReason)
        XCTAssertNil(tokenResponse?.accessToken)
    }
    
    func test_successTokenResponse_isParsedCorrectly() {
        let accessToken = "contoso"
        let idToken = "idToken"
        var jsonDictionary = [String: String]()
        jsonDictionary["access_token"] = accessToken
        jsonDictionary["id_token"] = idToken
        let tokenResponse = try? MSALNativeAuthCIAMTokenResponse(jsonDictionary: jsonDictionary)
        XCTAssertEqual(tokenResponse?.accessToken, accessToken)
        XCTAssertEqual(tokenResponse?.idToken, idToken)
        XCTAssertNil(tokenResponse?.challengeType)
        XCTAssertNil(tokenResponse?.redirectReason)
    }
}
