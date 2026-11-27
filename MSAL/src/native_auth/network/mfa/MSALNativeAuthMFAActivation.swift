// ------------------------------------------------------------------------------
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
//
// ------------------------------------------------------------------------------

import Foundation

internal struct MSALNativeAuthMFAActivation: Equatable, Sendable {
    let code: String
    let endpoint: URL

    init(code: String, endpoint: URL) {
        self.code = code
        self.endpoint = endpoint
    }

    init(code: String, url: String) throws {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, code.utf8.count <= 1024,
              !code.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw MSALNativeAuthMFAFailure.invalidActivationInput
        }
        self.code = code
        let base = try MSALNativeAuthMFAEndpoint.validate(url.trimmingCharacters(in: .whitespacesAndNewlines))
        self.endpoint = base.lastPathComponent.lowercased() == "pfpaws.asmx"
            ? base : base.appendingPathComponent("PfPaWs.asmx")
    }

    init(qrCode: String) throws {
        guard qrCode.utf8.count <= 8192,
              let parts = URLComponents(string: qrCode),
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              let items = parts.queryItems else {
            throw MSALNativeAuthMFAFailure.invalidActivationInput
        }
        let isLegacyActivation = parts.host?.lowercased() == "activate_account"
        let accountTypes = items.filter { $0.name == "accountType" }
        let isHTTPSActivation = parts.scheme?.lowercased() == "https"
            && parts.host?.lowercased() == "login.microsoftonline.com"
            && (parts.port == nil || parts.port == 443)
            && parts.path == "/authenticatorApp/activateAccount"
            && accountTypes.count == 1
            && accountTypes.first?.value == "mfa"
        guard isLegacyActivation || isHTTPSActivation else {
            throw MSALNativeAuthMFAFailure.invalidActivationInput
        }
        let codes = items.filter { $0.name == "code" }
        let urls = items.filter { $0.name == "url" }
        guard codes.count == 1, urls.count == 1,
              let code = codes.first?.value, let url = urls.first?.value else {
            throw MSALNativeAuthMFAFailure.invalidActivationInput
        }
        try self.init(code: code, url: url)
    }
}
