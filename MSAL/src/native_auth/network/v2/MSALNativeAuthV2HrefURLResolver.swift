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
/// Server hrefs own their tenant path and query, including `dc`. Relative hrefs use only
/// the configured authority's origin; absolute HTTPS hrefs are used unchanged.
/// Only fixed endpoints (initial authorize-challenge and token) use the configured path and `dc`.
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

    /// Builds the URL for a fixed endpoint by appending its path to the authority.
    func url(for endpoint: MSALNativeAuthEndpoint) throws -> URL {
        guard var components = URLComponents(url: authorityURL, resolvingAgainstBaseURL: true) else {
            throw MSALNativeAuthInternalError.invalidUrl
        }
        components.path += endpoint.rawValue
        return try applyingDataCenter(to: components)
    }

    /// Resolves a server-provided `_links` href into an absolute URL against the authority host.
    func url(forHref href: String, context: MSALNativeAuthRequestContext? = nil) throws -> URL {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var hrefComponents = URLComponents(string: trimmed) else {
            throw MSALNativeAuthInternalError.invalidUrl
        }

        if let scheme = hrefComponents.scheme {
            guard scheme.lowercased() == "https", let host = hrefComponents.host, !host.isEmpty else {
                throw MSALNativeAuthInternalError.invalidUrl
            }
        } else {
            guard hrefComponents.host == nil,
                  !trimmed.hasPrefix("//"),
                  !hrefComponents.path.isEmpty,
                  let authority = URLComponents(url: authorityURL, resolvingAgainstBaseURL: true) else {
                throw MSALNativeAuthInternalError.invalidUrl
            }
            hrefComponents.scheme = authority.scheme
            hrefComponents.host = authority.host
            hrefComponents.port = authority.port
            if !hrefComponents.path.hasPrefix("/") {
                hrefComponents.percentEncodedPath = "/" + hrefComponents.percentEncodedPath
            }
        }

        guard let url = hrefComponents.url else {
            throw MSALNativeAuthInternalError.invalidUrl
        }
        logMismatches(returnedURL: url, components: hrefComponents, context: context)
        return url
    }

    private func logMismatches(
        returnedURL: URL,
        components: URLComponents,
        context: MSALNativeAuthRequestContext?
    ) {
        let configuredTenant = authorityURL.path.split(separator: "/").first?.lowercased()
        let returnedTenant = returnedURL.path.split(separator: "/").first?.lowercased()
        if returnedURL.scheme?.lowercased() != authorityURL.scheme?.lowercased()
            || returnedURL.host?.lowercased() != authorityURL.host?.lowercased()
            || returnedURL.port != authorityURL.port
            || returnedTenant != configuredTenant {
            MSALNativeAuthLogger.log(
                level: .warning,
                context: context,
                format: "Native Auth V2: returned URL authority differs from the configured authority; using the server-provided URL."
            )
        }

        let returnedDataCenter = components.queryItems?.first(where: { $0.name == "dc" })?.value
        if returnedDataCenter != dataCenter {
            MSALNativeAuthLogger.log(
                level: .warning,
                context: context,
                format: "Native Auth V2: returned test slice (dc) differs from the configured test slice; using the server-provided query."
            )
        }
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
