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

final class MSALNativeAuthResetPasswordControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthResetPasswordController!
    private var requestProviderMock: MSALNativeAuthResetPasswordRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factoryMock: MSALNativeAuthResultFactoryMock!
    private var tokenResult = MSIDTokenResult()
    private var tokenResponse = MSIDAADTokenResponse()
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!

    private var resetPasswordStartRequestParamsStub: MSALNativeAuthResetPasswordStartRequestParameters {
        .init(
            config: MSALNativeAuthConfigStubs.configuration,
            context: contextMock,
            username: "username"
        )
    }

    override func setUpWithError() throws {
        requestProviderMock = .init()
        cacheAccessorMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        factoryMock = .init()

        sut = .init(clientId: MSALNativeAuthConfigStubs.configuration.clientId, cacheAccessor: cacheAccessorMock)

        try super.setUpWithError()
    }

    func test_resetPasswordController_Start() throws {
        let expectation = expectation(description: "ResetPasswordController")

        let username = "test@contoso.com"
        let context = MSALNativeAuthRequestContextMock(correlationId: defaultUUID)

        let mockDelegate = ResetPasswordStartDelegateSpy(expectation: expectation)

        sut.resetPassword(username: username, context: context, delegate: mockDelegate)

        wait(for: [expectation], timeout: 1)
    }



}
