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

final class SignInAfterSignUpStateTests: XCTestCase {

    private var sut: SignInAfterSignUpState!
    private var controller: MSALNativeAuthSignInControllerMock!
    private var correlationId: UUID = UUID()
    private let claimsRequestJson = "{}"
    private let scopes = ["scope"]
    private let username = "username"
    private let continuationToken = "continuationToken"

    override func setUp() {
        super.setUp()

        controller = .init()
        sut = .init(controller: controller, username: username, continuationToken: continuationToken, correlationId: correlationId)
    }

    func test_checkThatParametersSentToController_areExpected() {
        let exp = expectation(description: "signIn after signUp")

        let expectedError = SignInAfterSignUpError(type: .generalError, correlationId: correlationId)

        controller.continuationTokenResult = .init(.init(.error(error: SignInAfterSignUpError(type: .generalError, correlationId: correlationId)), correlationId: correlationId))

        let delegate = SignInAfterSignUpDelegateSpy(expectation: exp, expectedError: expectedError, expectedUserAccountResult: nil)

        let params = MSALNativeAuthSignInAfterSignUpParameters()
        params.scopes = scopes
        var error: NSError?
        params.claimsRequest = MSALClaimsRequest(jsonString: claimsRequestJson, error: &error)
        
        sut.signIn(parameters: params, delegate: delegate)
        wait(for: [exp], timeout: 1)
        
        XCTAssertEqual(controller.claimsRequestJson, claimsRequestJson)
        XCTAssertEqual(controller.username, username)
        XCTAssertEqual(controller.continuationToken, continuationToken)
        XCTAssertFalse(delegate.onSignInCompletedCalled)
        XCTAssertFalse(delegate.onRegisterStrongAuthCalled)
    }

}
