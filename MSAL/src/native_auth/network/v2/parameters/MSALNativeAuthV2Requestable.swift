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

/// Describes a single V2 native-auth request: each concrete parameter type knows its target URL,
/// HTTP method, body, body encoding and telemetry identity. `MSALNativeAuthV2RequestConfigurator`
/// turns any of these into a fully-configured `MSIDHttpRequest` that reuses the shared AAD request
/// pipeline (device-id headers, PkeyAuth, correlation, server telemetry).
protocol MSALNativeAuthV2Requestable {
    var context: MSALNativeAuthRequestContext { get }
    var httpMethod: String { get }
    var encoding: MSALNativeAuthUrlRequestEncoding { get }
    var apiId: MSALNativeAuthTelemetryApiId { get }
    var operationType: MSALNativeAuthOperationType { get }
    /// `true` only for the `/token` endpoint, which returns a plain OAuth response (not HAL) and must
    /// keep the default raw-JSON response serializer instead of the HAL serializer.
    var expectsRawJSONResponse: Bool { get }
    var body: [AnyHashable: Any] { get }
    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL
}

extension MSALNativeAuthV2Requestable {
    var httpMethod: String { "POST" }
    var expectsRawJSONResponse: Bool { false }
}
