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

final class MSALNativeAuthV2HrefURLResolverTests: XCTestCase {

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

    // MARK: - Absolute hrefs

    func test_url_forAbsoluteHref_isUsedAsIs() throws {
        let href = "https://contoso.example.com/foo/bar?x=1"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, href)
    }

    func test_url_forAbsoluteHref_whenDataCenterSet_appendsDc() throws {
        let url = try resolver(dataCenter: "ESTS-DC").url(forHref: "https://contoso.example.com/foo")
        XCTAssertEqual(url.absoluteString, "https://contoso.example.com/foo?dc=ESTS-DC")
    }

    // MARK: - Relative / templated hrefs

    func test_url_forTemplatedTenantHref_stripsTenantAndAnchorsOnAuthorityTenant() throws {
        let href = "{tenant}/api/v0.1/auth/methods/email/3f7/verify"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/verify")
    }

    func test_url_forLeadingTenantSegmentHref_dropsTenantUsingApiMarker() throws {
        let href = "/1eb974cd-0dc5-40a6-9f68-94b19f5535c5/api/v0.1/auth/methods/email/3f7/verify"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/verify")
    }

    func test_url_forHrefWithOauthMarker_dropsTenantUsingOauthMarker() throws {
        let href = "/1eb974cd/oauth2/v2.0/token"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(url.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/token")
    }

    func test_url_forHrefWithQuery_preservesHrefQuery() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/verify?dc=ESTS-PUB-SEASLR1"
        let url = try resolver().url(forHref: href)
        XCTAssertEqual(
            url.absoluteString,
            "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/verify?dc=ESTS-PUB-SEASLR1"
        )
    }

    func test_url_forHrefWithExistingDc_whenDataCenterSet_doesNotDuplicateDc() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/verify?dc=ESTS-EXISTING"
        let url = try resolver(dataCenter: "ESTS-NEW").url(forHref: href)
        XCTAssertEqual(
            url.absoluteString,
            "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/verify?dc=ESTS-EXISTING"
        )
    }

    func test_url_forRelativeHref_whenDataCenterSet_appendsDc() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/challenge"
        let url = try resolver(dataCenter: "ESTS-NEW").url(forHref: href)
        XCTAssertEqual(
            url.absoluteString,
            "https://login.microsoftonline.com/common/api/v0.1/auth/methods/email/3f7/challenge?dc=ESTS-NEW"
        )
    }
}
