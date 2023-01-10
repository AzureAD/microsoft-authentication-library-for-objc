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

@_implementationOnly import MSAL_Private

final class MSALNativeContext: MSIDRequestContext {

    private let _correlationId = UUID()

    func correlationId() -> UUID {
        _correlationId
    }

    func logComponent() -> String {
        MSIDVersion.sdkName()
    }

    func telemetryRequestId() -> String {
        MSIDTelemetry.sharedInstance().generateRequestId()
    }

    func appRequestMetadata() -> [AnyHashable: Any] {
        guard let metadata = Bundle.main.infoDictionary else {
            return [:]
        }

        let appName = metadata["CFBundleDisplayName"] ?? (metadata["CFBundleName"] ?? "")
        let appVersion = metadata["CFBundleShortVersionString"] ?? ""

        return [
            MSID_VERSION_KEY: MSIDVersion.sdkVersion() ?? "",
            MSID_APP_NAME_KEY: appName,
            MSID_APP_VER_KEY: appVersion
        ]
    }
}
