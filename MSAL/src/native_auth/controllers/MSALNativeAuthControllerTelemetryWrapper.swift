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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// The Controller sends this model to the public interface, which uses the `result` value to return to the user.
/// The `telemetryUpdate` gets called from the public interface, if it needs to tell the controller to update the telemetry
/// (ex: an optional delegate method not implemented by the external developer).
struct MSALNativeAuthControllerTelemetryWrapper<R> {
    let result: R
    let correlationId: UUID
    let telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)?

    init(_ result: R, correlationId: UUID, telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)? = nil) {
        self.result = result
        self.correlationId = correlationId
        self.telemetryUpdate = telemetryUpdate
    }
}
