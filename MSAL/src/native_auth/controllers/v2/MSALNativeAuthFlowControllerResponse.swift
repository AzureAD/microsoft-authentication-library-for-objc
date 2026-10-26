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

/// Wraps the controller result with the correlation id and an optional telemetry update closure.
struct MSALNativeAuthFlowControllerResponse {
    let result: MSALNativeAuthFlowResult
    let correlationId: UUID
    /// The public scenario reported to the app (defaults to `.unknown` when the flow is undetermined).
    let scenario: MSALNativeAuthFlowScenario
    let telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)?

    init(
        _ result: MSALNativeAuthFlowResult,
        correlationId: UUID,
        scenario: MSALNativeAuthFlowScenario = .unknown,
        telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)? = nil
    ) {
        self.result = result
        self.correlationId = correlationId
        self.scenario = scenario
        self.telemetryUpdate = telemetryUpdate
    }
}
