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

internal enum MSALNativeAuthMFAEndpoint {
    enum Policy: MSALNativeAuthMFARequestPolicy {
        case activation
        case phoneApp
        case graphDeletion

        func validate(_ request: URLRequest) throws {
            guard let url = request.url else { throw MSALNativeAuthMFAError.Reason.untrustedEndpoint }
            try validate(url)
            if case .graphDeletion = self {
                guard request.httpMethod == "DELETE", request.httpBody == nil else {
                    throw MSALNativeAuthMFAError.Reason.invalidResponse
                }
            }
        }

        func acceptsEmptyResponse(statusCode: Int) throws -> Bool {
            if case .graphDeletion = self {
                guard statusCode == 204 || statusCode == 404 else {
                    throw MSALNativeAuthMFAError.Reason.httpFailure(statusCode: statusCode)
                }
                return true
            }
            guard statusCode == 200 else {
                throw MSALNativeAuthMFAError.Reason.httpFailure(statusCode: statusCode)
            }
            return false
        }

        func validate(_ url: URL) throws {
            switch self {
            case .activation:
                _ = try MSALNativeAuthMFAEndpoint.validate(url.absoluteString)
            case .phoneApp:
                _ = try MSALNativeAuthMFAEndpoint.phoneApp(url.absoluteString)
            case .graphDeletion:
                try MSALNativeAuthMFAEndpoint.validateGraphDeletion(url)
            }
        }
    }

    static func validateGraphDeletion(_ url: URL) throws {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host == "graph.microsoft.com",
              parts.port == nil, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil else {
            throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
        }
        let segments = parts.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 7, segments[0].isEmpty,
              segments[1] == "v1.0", segments[2] == "users",
              UUID(uuidString: String(segments[3])) != nil,
              segments[4] == "authentication", segments[5] == "microsoftAuthenticatorMethods",
              !segments[6].isEmpty, segments[6].utf8.count <= 1024,
              segments[6].utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                  || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
        }
    }

    static func validate(_ value: String, allowsLegacyService: Bool = false) throws -> URL {
        try validate(value, allowsLegacyService: allowsLegacyService, allowsQuery: false)
    }

    private static func validate(_ value: String, allowsLegacyService: Bool, allowsQuery: Bool) throws -> URL {
        guard value.utf8.count <= 4096,
              let parts = URLComponents(string: value),
              parts.scheme?.lowercased() == "https",
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              (allowsQuery || parts.query == nil), parts.port == nil || parts.port == 443,
              let host = parts.host?.lowercased(),
              (["microsoft.com", "microsoft.us", "microsoft.cn"] + (allowsLegacyService ? ["phonefactor.net"] : [])).contains(where: {
                  host == $0 || host.hasSuffix("." + $0)
              }),
              let url = parts.url else {
            throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
        }
        return url
    }

    static func notification(_ value: String) throws -> URL {
        guard value.utf8.count <= 4096 else {
            throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
        }
        let absolute = value.contains("://") ? value : "https://" + value
        guard let parts = URLComponents(string: absolute) else {
            throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
        }
        if parts.percentEncodedPath.isEmpty, parts.query == nil, parts.fragment == nil {
            return try phoneApp(absolute + "/pad")
        }
        return try phoneApp(absolute)
    }

    static func phoneApp(_ value: String) throws -> URL {
        guard value.utf8.count <= 4096, !value.contains("\\"),
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              let parts = URLComponents(string: value),
              parts.url?.absoluteString == value,
              let host = parts.host, !host.contains("%"),
              ["/pad", "/mac/MobileAppCommunicator.svc", "/mac/MobileAppCommunicator.svc/"].contains(parts.percentEncodedPath) else {
            throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
        }
        let isMAC = parts.percentEncodedPath != "/pad"
        if let items = parts.queryItems {
            guard isMAC, !items.isEmpty,
                  Set(items.map(\.name)).count == items.count,
                  items.allSatisfy({ item in
                      guard ["su", "ignored"].contains(item.name), let value = item.value, !value.isEmpty else { return false }
                      return !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
                  }) else {
                throw MSALNativeAuthMFAError.Reason.untrustedEndpoint
            }
        }
        return try validate(value, allowsLegacyService: !isMAC, allowsQuery: isMAC)
    }
}
