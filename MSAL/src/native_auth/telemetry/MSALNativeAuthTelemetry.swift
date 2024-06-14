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
import TelemetryKit

protocol Telemetry {
    func logEvent(_ event: MSALNativeAuthTelemetryEvent)
}

struct MSALNativeAuthTelemetryEvent {
    enum Status {
        case ok
        case unset
        case error(description: String?)

        func toTKStatus() -> TKStatus {
            switch self {
            case .ok:
                return .ok
            case .unset:
                return .unset
            case .error(let description):
                return .error(description: description ?? "no error description")
            }
        }
    }

    let name: String
    var status: Status
    var properties: [String: Any]?
}

final class MSALNativeAuthTelemetry: Telemetry {

    static let shared: Telemetry = MSALNativeAuthTelemetry()

    private let telemetry: TelemetryKit

    private init() {
        do {
            telemetry = try TelemetryKit(
                sdk: .openTelemetry,
                tenantToken: "f6467ed73bdd47528a3b6d78f93b1eea-de7b8fbe-17ba-4b62-8d93-ff348afa2162-7691"
            )
        } catch {
            print(error)
            fatalError()
        }
    }

    func logEvent(_ event: MSALNativeAuthTelemetryEvent) {
        let event = TKEventProperties(name: event.name, status: event.status.toTKStatus(), properties: event.properties)
        telemetry.logEvent(event)
    }
}
