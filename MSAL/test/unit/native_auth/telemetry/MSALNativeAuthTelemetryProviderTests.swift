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

final class MSALNativeAuthTelemetryProviderTests: XCTestCase {

    private var sut : MSALNativeAuthTelemetryProviding!

    override func setUpWithError() throws {
        sut = MSALNativeAuthTelemetryProvider()
    }
    
    // MARK: Correct API Id tests
    func testTelemetryForSignUp_returnsCorrectApiId() {
        let result = sut.telemetryForSignUp(type: MSALNativeAuthSignUpType.signUpWithPassword)
        XCTAssertEqual(result.apiId, .telemetryApiIdSignUpCodeStart)
    }
    
    func testTelemetryForSignInWithCode_returnsCorrectApiId() {
        let result = sut.telemetryForSignIn(type: MSALNativeAuthSignInType.signInWithOTP)
        XCTAssertEqual(result.apiId, .telemetryApiIdSignInWithCodeStart)
    }
    
    func testTelemetryForRefreshToken_returnsCorrectApiId() {
        let result = sut.telemetryForToken(type: MSALNativeAuthTokenType.refreshToken)
        XCTAssertEqual(result.apiId, .telemetryApiIdToken)
    }
    
    func testTelemetryForResetPasswordStart_returnsCorrectApiId() {
        let result = sut.telemetryForResetPasswordStart(type: MSALNativeAuthResetPasswordStartType.resetPasswordStart)
        XCTAssertEqual(result.apiId, .telemetryApiIdResetPasswordStart)
    }
    
    func testTelemetryForResendCode_returnsCorrectApiId() {
        let result = sut.telemetryForResendCode(type: MSALNativeAuthResendCodeType.resendCode)
        XCTAssertEqual(result.apiId, .telemetryApiIdResendCode)
    }
    
    func testTelemetryForVerifyCode_returnsCorrectApiId() {
        let result = sut.telemetryForVerifyCode(type: MSALNativeAuthVerifyCodeType.verifyCode)
        XCTAssertEqual(result.apiId, .telemetryApiIdVerifyCode)
    }
    
    func testTelemetryForSignOut_returnsCorrectApiId() {
        let result = sut.telemetryForSignOut(type: MSALNativeAuthSignOutType.signOutAction)
        XCTAssertEqual(result.apiId, .telemetryApiIdSignOut)
    }
    
    // MARK: Correct Operation Type tests
    func testTelemetryForSignUp_returnsCorrectOperationType() {
        let result = sut.telemetryForSignUp(type: MSALNativeAuthSignUpType.signUpWithOTP)
        XCTAssertEqual(result.operationType, MSALNativeAuthSignUpType.signUpWithOTP.rawValue)
    }
    
    func testTelemetryForToken_returnsCorrectOperationType() {
        let result = sut.telemetryForToken(type: MSALNativeAuthTokenType.refreshToken)
        XCTAssertEqual(result.operationType, MSALNativeAuthTokenType.refreshToken.rawValue)
    }
}
