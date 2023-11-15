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

@testable import MSAL
import XCTest

final class DispatchAccessTokenRetrieveCompletedTests: XCTestCase {

    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: CredentialsDelegateDispatcher!

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchAccessTokenRetrieveCompleted_whenDelegateMethodsAreImplemented() async {
        let expectedToken = "token"
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedAccessToken: expectedToken)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        await sut.dispatchAccessTokenRetrieveCompleted(accessToken: expectedToken)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.expectedAccessToken, expectedToken)
    }

    func test_dispatchAccessTokenRetrieveCompleted_whenDelegateOptionalMethodsNotImplemented() async {
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: MSALNativeAuthErrorMessage.requiredDelegateMethod("onAccessTokenRetrieveCompleted"))
        let delegate = CredentialsDelegateOptionalMethodsNotImplemented(expectation: delegateExp, expectedError: expectedError)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? RetrieveAccessTokenError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedResult = MSALNativeAuthUserAccountResultStub.result

        await sut.dispatchAccessTokenRetrieveCompleted(accessToken: "token")

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.expectedError)

        func checkError(_ error: RetrieveAccessTokenError?) {
            XCTAssertEqual(error?.type, .generalError)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
        }
    }
}
