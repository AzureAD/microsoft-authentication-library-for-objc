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

/// Builds request URLs for the Native Auth V2 flows.
///
/// V2 is server-driven, so most steps follow `_links` hrefs returned by the server. Those
/// hrefs may be absolute, or relative/templated (e.g. `{tenant}/api/v0.1/auth/...`). This
/// resolver normalises a server href against the configured authority host, and also builds
/// URLs for the fixed ``MSALNativeAuthV2Endpoint`` cases. The slice/data-center query
/// parameter is appended consistently, mirroring the V1 `makeEndpointUrl` behaviour.
struct MSALNativeAuthV2HrefURLResolver {

    private let authorityURL: URL
    private let dataCenter: String?

    init(config: MSALNativeAuthInternalConfiguration) {
        self.authorityURL = config.authority.url
        self.dataCenter = config.sliceConfig?.dc
    }

    init(authorityURL: URL, dataCenter: String?) {
        self.authorityURL = authorityURL
        self.dataCenter = dataCenter
    }

    /// Builds the URL for a fixed V2 endpoint by appending its path to the authority.
    func url(for endpoint: MSALNativeAuthV2Endpoint) throws -> URL {
        guard var components = URLComponents(url: authorityURL, resolvingAgainstBaseURL: true) else {
            throw MSALNativeAuthInternalError.invalidUrl
        }
        components.path += endpoint.rawValue
        return try applyingDataCenter(to: components)
    }

    /// Resolves a server-provided `_links` href into an absolute URL against the authority host.
    func url(forHref href: String) throws -> URL {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)

        // Absolute href: use as-is (still append the data-center parameter).
        if let absolute = URL(string: trimmed), let scheme = absolute.scheme, scheme.hasPrefix("http") {
            guard let components = URLComponents(url: absolute, resolvingAgainstBaseURL: false) else {
                throw MSALNativeAuthInternalError.invalidUrl
            }
            return try applyingDataCenter(to: components)
        }

        // Relative / templated href: the href may already carry its own query string
        // (e.g. `?dc=...`), so parse it with URLComponents to separate path from query
        // rather than folding the query into the path. Strip any leading tenant
        // placeholder and resolve the path against the authority's scheme + host.
        guard let hrefComponents = URLComponents(string: normalizedHref(from: trimmed)) else {
            throw MSALNativeAuthInternalError.invalidUrl
        }

        guard var components = URLComponents(url: authorityURL, resolvingAgainstBaseURL: true) else {
            throw MSALNativeAuthInternalError.invalidUrl
        }
        components.path = hrefComponents.path
        components.percentEncodedQuery = hrefComponents.percentEncodedQuery
        return try applyingDataCenter(to: components)
    }

    private func normalizedHref(from href: String) -> String {
        var result = href

        // Drop a leading `{tenant}` placeholder segment if present.
        if result.hasPrefix("{tenant}") {
            result = String(result.dropFirst("{tenant}".count))
        }

        // The server returns host-relative hrefs; ensure a leading slash so URLComponents
        // parses the leading segment as a path rather than a scheme/host.
        if !result.hasPrefix("/") {
            result = "/" + result
        }

        return result
    }

    private func applyingDataCenter(to components: URLComponents) throws -> URL {
        var components = components
        if let dataCenter = dataCenter {
            var queryItems = components.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "dc" }) {
                queryItems.append(URLQueryItem(name: "dc", value: dataCenter))
            }
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw MSALNativeAuthInternalError.invalidUrl
        }
        return url
    }
}
