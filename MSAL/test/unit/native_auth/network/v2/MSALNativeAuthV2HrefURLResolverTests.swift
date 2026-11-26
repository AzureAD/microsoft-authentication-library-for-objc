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

import XCTest
@testable import MSAL

final class MSALNativeAuthV2HrefURLResolverTests: MSALNativeAuthTestCase {

    private let authorityURL = URL(string: "https://login.microsoftonline.com/common")!

    private func resolver(dataCenter: String? = nil) -> MSALNativeAuthV2HrefURLResolver {
        return MSALNativeAuthV2HrefURLResolver(authorityURL: authorityURL, dataCenter: dataCenter)
    }

    // MARK: - Fixed endpoints

    func test_url_forAuthorizeChallengeEndpoint_appendsPathToAuthority() throws {
        let url = try resolver().url(for: .authorizeChallenge)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/authorize-challenge")
    }

    func test_url_forTokenEndpoint_appendsPathToAuthority() throws {
        let url = try resolver().url(for: .token)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/token")
    }

    func test_url_forEndpoint_whenDataCenterSet_appendsDcQueryItem() throws {
        let url = try resolver(dataCenter: "ESTS-PUB-TEST").url(for: .token)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/token?dc=ESTS-PUB-TEST")
    }

    func test_url_forFixedEndpoints_normalizesAuthorityTrailingSlash() throws {
        let tenantId = "4710d5e4-43bb-4ff9-89af-30ed8fe31c6d"
        for origin in ["https://custom.example.com", "https://contoso.ciamlogin.com"] {
            for tenant in [tenantId, "contoso.onmicrosoft.com"] {
                for trailingSlash in ["", "/"] {
                    let authority = try XCTUnwrap(URL(string: "\(origin)/\(tenant)\(trailingSlash)"))
                    let sut = MSALNativeAuthV2HrefURLResolver(authorityURL: authority, dataCenter: nil)
                    for endpoint in [MSALNativeAuthEndpoint.authorizeChallenge, .token] {
                        XCTAssertEqual(
                            try sut.url(for: endpoint).absoluteString,
                            "\(origin)/\(tenant)\(endpoint.rawValue)"
                        )
                    }
                }
            }
        }
    }

    func test_url_forFixedEndpoints_withTrailingSlash_preservesQueryAndDataCenter() throws {
        for (query, expectedQuery) in [
            ("?extra=value", "?extra=value&dc=developer-dc"),
            ("?dc=authority-dc&extra=value", "?dc=authority-dc&extra=value")
        ] {
            let authority = try XCTUnwrap(URL(string: "https://custom.example.com/contoso.onmicrosoft.com/\(query)"))
            let sut = MSALNativeAuthV2HrefURLResolver(authorityURL: authority, dataCenter: "developer-dc")
            for endpoint in [MSALNativeAuthEndpoint.authorizeChallenge, .token] {
                XCTAssertEqual(
                    try sut.url(for: endpoint).absoluteString,
                    "https://custom.example.com/contoso.onmicrosoft.com\(endpoint.rawValue)\(expectedQuery)"
                )
            }
        }
    }

    // MARK: - Absolute hrefs

    func test_url_forEmptyHref_throws() {
        XCTAssertThrowsError(try resolver().url(forHref: "")) { error in
            XCTAssertEqual(error as? MSALNativeAuthInternalError, .invalidUrl)
        }
    }

    func test_url_forWhitespaceOnlyHref_throws() {
        XCTAssertThrowsError(try resolver().url(forHref: " \t\r\n ")) { error in
            XCTAssertEqual(error as? MSALNativeAuthInternalError, .invalidUrl)
        }
    }

    func test_url_forHrefWithSurroundingWhitespace_resolvesTrimmedHref() throws {
        let hrefs = [
            "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/challenge",
            "/common/api/v0.1/auth/methods/email/3f7/challenge",
            "common/api/v0.1/auth/methods/email/3f7/challenge"
        ]
        for href in hrefs {
            let url = try resolver().url(forHref: " \t\(href)\r\n ")
            XCTAssertEqual(
                url.absoluteString,
                "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/challenge"
            )
        }
    }

    func test_url_forAbsoluteHref_isUsedAsIs() throws {
        let href = "https://contoso.example.com/foo/bar?x=1"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, href)
    }

    func test_url_forAbsoluteHref_whenDataCenterSet_doesNotInjectDc() throws {
        let url = try resolver(dataCenter: "ESTS-DC").url(forHref: "https://contoso.example.com/foo")
        XCTAssertEqual(url.absoluteString, "https://contoso.example.com/foo")
    }

    func test_url_forMalformedAbsoluteHref_throws() {
        XCTAssertThrowsError(try resolver().url(forHref: "https://")) { error in
            XCTAssertEqual(error as? MSALNativeAuthInternalError, .invalidUrl)
        }
    }

    // MARK: - Relative hrefs

    func test_url_forLeadingTenantSegmentHref_preservesReturnedTenant() throws {
        let href = "/1eb974cd-0dc5-40a6-9f68-94b19f5535c5/api/v0.1/auth/methods/email/3f7/verify"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com" + href)
    }

    func test_url_forHrefWithOauthMarker_preservesReturnedTenant() throws {
        let href = "/1eb974cd/oauth2/v2.0/token"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com" + href)
    }

    func test_url_forHrefWithQuery_preservesHrefQuery() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/verify?dc=ESTS-PUB-SEASLR1"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(
            url.absoluteString,
            "https://login.microsoftonline.com" + href
        )
    }

    func test_url_forHrefWithExistingDc_whenDataCenterSet_doesNotDuplicateDc() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/verify?dc=ESTS-EXISTING"
        let url = try resolver(dataCenter: "ESTS-NEW").url(forHref: href)
        XCTAssertEqual(
            url.absoluteString,
            "https://login.microsoftonline.com" + href
        )
    }

    func test_url_forRelativeHref_whenDataCenterSet_doesNotInjectDc() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/challenge"
        let url = try resolver(dataCenter: "ESTS-NEW").url(forHref: href)
        XCTAssertEqual(
            url.absoluteString,
            "https://login.microsoftonline.com" + href
        )
    }

    func test_url_forServerHref_usesOriginAndReturnedPathForEveryAuthorityForm() throws {
        let tenantId = "4710d5e4-43bb-4ff9-89af-30ed8fe31c6d"
        let tenantDomain = "contoso.onmicrosoft.com"
        for origin in ["https://custom.example.com", "https://contoso.ciamlogin.com"] {
            for configuredTenant in [tenantId, tenantDomain] {
                for returnedTenant in [tenantId, tenantDomain] {
                    for query in ["", "?dc=ESTS-PUB-SEASLR1-FD000-TEST1-100&extra=a%2Bb%26c&extra=second"] {
                        let authority = try XCTUnwrap(URL(string: "\(origin)/\(configuredTenant)?dc=authority-dc&ignored=value"))
                        let sut = MSALNativeAuthV2HrefURLResolver(authorityURL: authority, dataCenter: "developer-dc")
                        let href = "/\(returnedTenant)/api/v2.0/signin/start\(query)"
                        XCTAssertEqual(try sut.url(forHref: href).absoluteString, origin + href)
                    }
                }
            }
        }
    }

    func test_url_forAbsoluteContinueHref_preservesOriginTenantAndEncodedQuery() throws {
        for query in ["", "?dc=server-dc&extra=a%2Bb%26c&extra=second"] {
            let href = "https://contoso.ciamlogin.com/server-tenant/oauth2/v2.0/authorize-challenge\(query)"
            XCTAssertEqual(try resolver(dataCenter: "developer-dc").url(forHref: href).absoluteString, href)
        }
    }

    func test_url_forRelativeHref_preservesEncodedPathAndAuthorityPort() throws {
        let authority = try XCTUnwrap(URL(string: "https://custom.example.com:8443/configured-tenant/"))
        let sut = MSALNativeAuthV2HrefURLResolver(authorityURL: authority, dataCenter: nil)
        let href = "/server-tenant/api/v2.0/auth/methods/id%2Fpart?dc=server&value=a%20b"
        XCTAssertEqual(try sut.url(forHref: href).absoluteString, "https://custom.example.com:8443" + href)
    }

    func test_url_forUnsafeHref_throws() {
        for href in ["http://contoso.com/tenant/api", "//contoso.com/tenant/api"] {
            XCTAssertThrowsError(try resolver().url(forHref: href)) { error in
                XCTAssertEqual(error as? MSALNativeAuthInternalError, .invalidUrl)
            }
        }
    }

    func test_url_forMismatchedAuthority_logsWarningWithoutURLValues() throws {
        let expectation = expectation(description: "Authority mismatch warning")
        Self.logger.expectation = expectation
        let href = "https://different.example.com/server-tenant/api/v2.0/signin/start?secret=private-value"

        _ = try resolver().url(forHref: href)

        wait(for: [expectation], timeout: 1)
        let messages = Self.logger.messages.compactMap { $0 as? String }.joined()
        XCTAssertTrue(messages.contains("returned URL authority differs"))
        XCTAssertEqual(Self.logger.level, .warning)
        XCTAssertFalse(messages.contains("different.example.com"))
        XCTAssertFalse(messages.contains("private-value"))
    }

    func test_url_forMismatchedSlice_logsWarningAndDoesNotOverrideServerQuery() throws {
        for query in ["", "?dc=server-dc"] {
            Self.logger.reset()
            let expectation = expectation(description: "Test slice mismatch warning")
            Self.logger.expectation = expectation
            let href = "/common/api/v2.0/signin/start" + query

            XCTAssertEqual(
                try resolver(dataCenter: "developer-dc").url(forHref: href).absoluteString,
                "https://login.microsoftonline.com" + href
            )

            wait(for: [expectation], timeout: 1)
            let messages = Self.logger.messages.compactMap { $0 as? String }.joined()
            XCTAssertTrue(messages.contains("returned test slice (dc) differs"))
            XCTAssertEqual(Self.logger.level, .warning)
        }
    }

    func test_url_forMatchingAuthorityAndSlice_doesNotLogMismatchWarnings() throws {
        let expectation = expectation(description: "No mismatch warnings")
        expectation.isInverted = true
        Self.logger.expectation = expectation

        _ = try resolver(dataCenter: "same-dc").url(forHref: "/common/api/v2.0/signin/start?dc=same-dc")
        _ = try resolver().url(forHref: "/common/api/v2.0/signin/start")

        wait(for: [expectation], timeout: 0.1)
    }
}
