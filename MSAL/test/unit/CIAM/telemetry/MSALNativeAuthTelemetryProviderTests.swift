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
    
    // MARK: Correct API Id tests
    func testTelemetryForSignUp_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForSignUp(type: MSALNativeAuthSignUpType.signUpWithPassword)
        XCTAssertEqual(result.apiId, .telemetryApiIdSignUp)
    }
    
    func testTelemetryForSignIn_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForSignIn(type: MSALNativeAuthSignInType.signInWithPassword)
        XCTAssertEqual(result.apiId, .telemetryApiIdSignIn)
    }
    
    func testTelemetryForRefreshToken_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForRefreshToken(type: MSALNativeAuthTokenRefreshType.noCacheLookupInvolved)
        XCTAssertEqual(result.apiId, .telemetryApiIdRefreshToken)
    }
    
    func testTelemetryForResetPasswordStart_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForResetPasswordStart(type: MSALNativeAuthResetPasswordStartType.resetPasswordStart)
        XCTAssertEqual(result.apiId, .telemetryApiIdResetPasswordStart)
    }
    
    func testTelemetryForResetPasswordComplete_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForResetPasswordComplete(type: MSALNativeAuthResetPasswordCompleteType.resetPasswordComplete)
        XCTAssertEqual(result.apiId, .telemetryApiIdResetPasswordComplete)
    }
    
    func testTelemetryForResendCode_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForResendCode(type: MSALNativeAuthResendCodeType.resendCode)
        XCTAssertEqual(result.apiId, .telemetryApiIdResendCode)
    }
    
    func testTelemetryForVerifyCode_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForVerifyCode(type: MSALNativeAuthVerifyCodeType.verifyCode)
        XCTAssertEqual(result.apiId, .telemetryApiIdVerifyCode)
    }
    
    func testTelemetryForSignOut_returnsCorrectApiId() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForSignOut(type: MSALNativeAuthSignOutType.signOutAction)
        XCTAssertEqual(result.apiId, .telemetryApiIdSignOut)
    }
    
    // MARK: Correct Operation Type tests
    func testTelemetryForSignUp_returnsCorrectOperationType() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForSignUp(type: MSALNativeAuthSignUpType.signUpWithOTP)
        XCTAssertEqual(result.operationType, MSALNativeAuthSignUpType.signUpWithOTP.rawValue)
    }
    
    func testTelemetryForRefreshToken_returnsCorrectOperationType() {
        let result = MSALNativeAuthTelemetryProvider.telemetryForRefreshToken(type: MSALNativeAuthTokenRefreshType.expiredAT)
        XCTAssertEqual(result.operationType, MSALNativeAuthTokenRefreshType.expiredAT.rawValue)
    }
}
