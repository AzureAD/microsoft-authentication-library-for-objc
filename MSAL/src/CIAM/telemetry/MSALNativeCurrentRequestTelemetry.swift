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

import Foundation
@_implementationOnly import MSAL_Private

class MSALNativeCurrentRequestTelemetry : NSObject, MSIDTelemetryStringSerializable {
    var schemaVersion: Int!
    var apiId: MSALNativeTelemetryApiId!
    var operationType: MSALNativeOperationType!
    var platformFields: [String]?
    
    convenience init(apiId: MSALNativeTelemetryApiId,
                     operationType: MSALNativeOperationType,
                     platformFields: [String]?) {
        self.init()
        self.schemaVersion = HTTP_REQUEST_TELEMETRY_SCHEMA_VERSION
        self.apiId = apiId
        self.operationType = operationType
        self.platformFields = platformFields
    }
    
    func telemetryString() -> String {
        return serializeCurrentTelemetryString() ?? ""
    }
    
    func serializeCurrentTelemetryString() -> String? {
        let currentTelemetryFields = createSerializedItem()
        return currentTelemetryFields.serialize()
    }
    
    func createSerializedItem() -> MSIDCurrentRequestTelemetrySerializedItem {
        let defaultFields = [NSNumber.init(integerLiteral: apiId.rawValue), NSNumber.init(integerLiteral: operationType)]
        return MSIDCurrentRequestTelemetrySerializedItem.init(schemaVersion: NSNumber.init(integerLiteral: schemaVersion),
                                                                defaultFields: defaultFields,
                                                                platformFields: platformFields)
    }
}
