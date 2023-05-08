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

final class MSALNativeAuthResponseValidatorTest: MSALNativeAuthTestCase {
    
    private var sut: MSALNativeAuthResponseValidator!
    private var responseHandler: MSALNativeAuthResponseHandlerMock!
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private var tokenResponse = MSIDTokenResponse()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        responseHandler = MSALNativeAuthResponseHandlerMock()
        sut = MSALNativeAuthResponseValidator(responseHandler: responseHandler)
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
    }
    
    func test_validateAndConvert_handleSuccessfulResult() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(result: MSIDTokenResult())
        responseHandler.expectedContext = context
        responseHandler.expectedValidateAccount = true
        XCTAssertNotNil(sut.validateAndConvertTokenResponse(tokenResponse, context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration))
    }
    
    func test_validateAndConvert_returnNilWhenErrorOccurred() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthError.generalError)
        XCTAssertNil(sut.validateAndConvertTokenResponse(tokenResponse, context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration))
    }
}
