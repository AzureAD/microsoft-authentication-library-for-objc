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

@_implementationOnly import MSAL_Private
@testable import MSAL
import XCTest

final class DispatchAccessTokenRetrieveCompletedTests: XCTestCase {

    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: CredentialsDelegateDispatcher!
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchAccessTokenRetrieveCompleted_whenDelegateMethodsAreImplemented() async {
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "accessToken"
        accessToken.scopes = ["scope1", "scope2"]
        let refreshToken = MSIDRefreshToken()
        refreshToken.refreshToken = "refreshToken"
        let rawIdToken = "rawIdToken"
        let authTokens = MSALNativeAuthTokens(accessToken: accessToken,
                                              refreshToken: refreshToken,
                                              rawIdToken: rawIdToken)
        let expectedResult = MSALNativeAuthTokenResult(authTokens: authTokens)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes.array as? [String] ?? []
        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        await sut.dispatchAccessTokenRetrieveCompleted(result: expectedResult, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.expectedResult, expectedResult)
    }

    func test_dispatchAccessTokenRetrieveCompleted_whenDelegateOptionalMethodsNotImplemented() async {
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onAccessTokenRetrieveCompleted"), correlationId: correlationId)
        let delegate = CredentialsDelegateOptionalMethodsNotImplemented(expectation: delegateExp, expectedError: expectedError)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? RetrieveAccessTokenError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "accessToken"
        let refreshToken = MSIDRefreshToken()
        refreshToken.refreshToken = "refreshToken"
        let rawIdToken = "rawIdToken"
        let authTokens = MSALNativeAuthTokens(accessToken: accessToken,
                                              refreshToken: refreshToken,
                                              rawIdToken: rawIdToken)

        await sut.dispatchAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult(authTokens: authTokens), correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.expectedError)

        func checkError(_ error: RetrieveAccessTokenError?) {
            XCTAssertEqual(error?.type, .generalError)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }
}
