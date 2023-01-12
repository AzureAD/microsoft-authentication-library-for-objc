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

final class MSALNativeTelemetryProviderTests: XCTestCase {

    // MARK: Correct API Id tests
    func testTelemetryForSignUp_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForSignUp(type: MSALNativeSignUpType.MSALNativeSignUpWithPassword)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetrySignUp)
    }
    
    func testTelemetryForSignIn_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForSignIn(type: MSALNativeSignInType.MSALNativeSignInithPassword)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetrySignIn)
    }
    
    func testTelemetryForRefreshToken_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForRefreshToken(type: MSALNativeTokenRefreshType.noCacheLookupInvolved)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetryRefreshToken)
    }
    
    func testTelemetryForResetPasswordStart_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForResetPasswordStart(type: MSALNativeResetPasswordStartType.MSALNativeResetPasswordStart)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetryResetPasswordStart)
    }
    
    func testTelemetryForResetPasswordComplete_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForResetPasswordComplete(type: MSALNativeResetPasswordCompleteType.MSALNativeResetPasswordComplete)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetryResetPasswordComplete)
    }
    
    func testTelemetryForResendCode_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForResendCode(type: MSALNativeResendCodeType.MSALNativeResendCode)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetryResendCode)
    }
    
    func testTelemetryForVerifyCode_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForVerifyCode(type: MSALNativeVerifyCodeType.MSALNativeVerifyCode)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetryVerifyCode)
    }
    
    func testTelemetryForSignOut_returnsCorrectApiId() {
        let result = MSALNativeTelemetryProvider.telemetryForSignOut(type: MSALNativeSignOutType.MSALNativeTelemetrySignOutAction)
        XCTAssertEqual(result.apiId, .MSALNativeTelemetrySignOut)
    }
    
    // MARK: Correct Operation Type tests
    func testTelemetryForSignUp_returnsCorrectOperationType() {
        let result = MSALNativeTelemetryProvider.telemetryForSignUp(type: MSALNativeSignUpType.MSALNativeSignUpWithOTP)
        XCTAssertEqual(result.operationType, MSALNativeSignUpType.MSALNativeSignUpWithOTP.rawValue)
    }
    
    func testTelemetryForRefreshToken_returnsCorrectOperationType() {
        let result = MSALNativeTelemetryProvider.telemetryForRefreshToken(type: MSALNativeTokenRefreshType.expiredAT)
        XCTAssertEqual(result.operationType, MSALNativeTokenRefreshType.expiredAT.rawValue)
    }
}
