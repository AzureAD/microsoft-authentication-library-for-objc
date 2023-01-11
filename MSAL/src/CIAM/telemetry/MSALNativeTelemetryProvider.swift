//
//  MSALNativeTelemetryProvider.swift
//  MSAL
//
//  Created by Silviu Petrescu on 11/01/2023.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import Foundation
class MSALNativeTelemetryProvider {
    static func telemetryForSignUp(type: MSALNativeSignUpType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignUp,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForSignIn(type: MSALNativeSignInType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignIn,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForRefreshToken(type: MSALNativeTokenRefreshType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetryRefreshToken,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForResetPasswordStart(type: MSALNativeResetPasswordStartType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetryResetPasswordStart,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForResetPasswordComplete(type: MSALNativeResetPasswordCompleteType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetryResetPasswordStart,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForResendCode(type: MSALNativeResendCodeType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetryResendCode,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForVerifyCode(type: MSALNativeVerifyCodeType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetryVerifyCode,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }
    
    static func telemetryForSignOut(type: MSALNativeSignOutType) -> MSALNativeCurrentRequestTelemetry {
        return MSALNativeCurrentRequestTelemetry(apiId: .MSALNativeTelemetrySignOut,
                                                 operationType: type.rawValue,
                                                 platformFields: nil)
    }    
}
