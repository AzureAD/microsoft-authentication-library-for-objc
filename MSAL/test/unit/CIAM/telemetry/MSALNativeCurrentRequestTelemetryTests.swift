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
    
    func testURLCache() {
        let cache = URLCache.shared
        let urlResponse = URLResponse(url: URL(string: "www.contoso.com")!, mimeType: nil, expectedContentLength: 1, textEncodingName: nil)
        let response = CachedURLResponse(response: urlResponse, data: Data("TestString".utf8))
        let request = getRequest()
        cache.storeCachedResponse(response, for: request)
        let storedResponse1 = cache.cachedResponse(for: request)
        let request2 = getRequest()
        let storedResponse2 = cache.cachedResponse(for: request2)
        XCTAssertEqual(storedResponse1, storedResponse2)    }
    private func getRequest() -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: "www.contoso.com")!)
        urlRequest.httpMethod = "GET"
        return urlRequest
        
    }
}
