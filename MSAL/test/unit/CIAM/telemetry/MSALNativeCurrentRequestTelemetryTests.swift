//
//  MSALNativeCurrentRequestTelemetryTests.swift
//  MSAL iOS Unit Tests
//
//  Created by Silviu Petrescu on 12/01/2023.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

final class MSALNativeCurrentRequestTelemetryTests: XCTestCase {
    
    func testSerialization_whenValidProperties_shouldCreateString() {
        let telemetry = MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignUp,
                                                          operationType: MSALNativeSignUpType.MSALNativeSignUpWithPassword.rawValue,
                                                          platformFields: nil)
        let result = telemetry.telemetryString()
        XCTAssertEqual(result, "4|75001,0|")
    }
    
    
    
    

    func testSerialization_whenSignUpType_SignUpOTP_shouldCreateString() {
        let telemetry = MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignUp,
                                                          operationType: MSALNativeSignUpType.MSALNativeSignUpWithOTP.rawValue,
                                                          platformFields: nil)
        let result = telemetry.telemetryString()
        XCTAssertEqual(result, "4|75001,1|")
    }

    func testSerialization_withOnePlatfomField_shouldCreateString() {
        let telemetry = MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignUp,
                                                          operationType: MSALNativeSignUpType.MSALNativeSignUpWithPassword.rawValue,
                                                          platformFields: ["iPhone14,5"])
        let result = telemetry.telemetryString()
        XCTAssertEqual(result, "4|75001,0|iPhone14,5")
    }
    
    func testSerialization_withMultiplePlatfomField_shouldCreateString() {
        let telemetry = MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignUp,
                                                          operationType: MSALNativeSignUpType.MSALNativeSignUpWithPassword.rawValue,
                                                          platformFields: ["iPhone14,5","iOS 16.0"])
        let result = telemetry.telemetryString()
        XCTAssertEqual(result, "4|75001,0|iPhone14,5,iOS 16.0")
    }
    
    func testSerialization_whenNilProperties_shouldCreateEmptyString() {
        let telemetry = MSALNativeCurrentRequestTelemetry()
        let result = telemetry.telemetryString()
        XCTAssertEqual(result, "0|0,0|")
    }
}
