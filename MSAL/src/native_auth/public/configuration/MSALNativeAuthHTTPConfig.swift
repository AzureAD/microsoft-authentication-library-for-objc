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

@objcMembers
public final class MSALNativeAuthHTTPConfig: MSALHTTPConfig {

    /// HTTP header keys that are reserved for internal SDK use and cannot be set via ``customHeaders``.
    /// Any headers provided in ``customHeaders`` whose keys match entries in this list (case-insensitive) will be ignored.
    public static let restrictedHeaders: Set<String> = [
        "Content-Type",
        "Accept",
        "return-client-request-id",
        "x-ms-PkeyAuth+",
        "client-request-id",
        "x-client-CPU",
        "x-client-SKU",
        "x-app-name",
        "x-app-ver",
        "x-client-OS",
        "x-client-Ver",
        "x-client-DM",
        "x-client-current-telemetry",
        "x-client-last-telemetry"
    ]

    private static var _customHeaders: [String: String] = [:]

    /// Custom HTTP headers to include in every network request.
    /// Headers whose keys conflict with internally reserved SDK headers (see ``restrictedHeaders``) are ignored.
    public static var customHeaders: [String: String] {
        get { return _customHeaders }
        set {
            var filteredHeaders = newValue
            for key in newValue.keys
            {
                if restrictedHeaders.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame })
                {
                    MSALNativeAuthLogger.log(
                        level: .warning,
                        context: nil,
                        format: "MSALNativeAuthHTTPConfig: Custom header '\(key)' is not allowed as it conflicts with an internal SDK header and will be ignored."
                    )
                    filteredHeaders.removeValue(forKey: key)
                }
            }
            _customHeaders = filteredHeaders
            MSALNativeAuthLogger.log(level: .info, context: nil, format: "MSALNativeAuthHTTPConfig: customHeaders keys set - \(Array(_customHeaders.keys))")
        }
    }
}
