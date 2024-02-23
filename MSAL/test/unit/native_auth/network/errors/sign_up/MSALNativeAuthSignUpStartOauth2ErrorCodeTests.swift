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

final class MSALNativeAuthSignUpStartOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthSignUpStartOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 8)
    }

    func test_invalidGrant() {
        XCTAssertEqual(sut.invalidGrant.rawValue, "invalid_grant")
    }

    func test_invalidRequest() {
        XCTAssertEqual(sut.invalidRequest.rawValue, "invalid_request")
    }

    func test_unauthorizedClient() {
        XCTAssertEqual(sut.unauthorizedClient.rawValue, "unauthorized_client")
    }
    
    func test_unsupportedChallengeType() {
        XCTAssertEqual(sut.unsupportedChallengeType.rawValue, "unsupported_challenge_type")
    }

    func test_userAlreadyExists() {
        XCTAssertEqual(sut.userAlreadyExists.rawValue, "user_already_exists")
    }

    func test_attributesRequired() {
        XCTAssertEqual(sut.attributesRequired.rawValue, "attributes_required")
    }
    
    func test_unsupportedAuthMethod() {
        XCTAssertEqual(sut.unsupportedAuthMethod.rawValue, "unsupported_auth_method")
    }
}
