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

#import "MSALBaseAADUITest.h"
#import "XCUIElement+CrossPlat.h"

@implementation MSALBaseAADUITest

#pragma mark - Shared parameterized steps

- (NSString *)runSharedAADLoginWithClientId:(NSString *)clientId
                                     scopes:(NSString *)scopes
                       expectedResultScopes:(NSArray *)expectedScopes
                                redirectUri:(NSString *)redirectUri
                                  authority:(NSString *)authority
                                 uiBehavior:(NSString *)uiBehavior
                                  loginHint:(NSString *)loginHint
                          accountIdentifier:(NSString *)accountIdentifier
                          validateAuthority:(BOOL)validateAuthority
                         useEmbeddedWebView:(BOOL)useEmbedded
                    useSafariViewController:(BOOL)useSFController
                            expectedAccount:(MSIDTestAccount *)testAccount
{
    NSDictionary *config = [self configDictionaryWithClientId:clientId
                                                       scopes:scopes
                                                  redirectUri:redirectUri
                                                    authority:authority
                                                   uiBehavior:uiBehavior
                                                    loginHint:loginHint
                                            validateAuthority:validateAuthority
                                           useEmbeddedWebView:useEmbedded
                                      useSafariViewController:useSFController
                                            accountIdentifier:accountIdentifier];
    [self acquireToken:config];

    if (!useSFController
        && !useEmbedded)
    {
        [self allowSFAuthenticationSessionAlert];
    }

    [self assertAuthUIAppearWithEmbedded:useEmbedded
                    safariViewController:useSFController];

    if (!loginHint && !accountIdentifier)
    {
        [self aadEnterEmail];
    }

    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];

    [self assertAccessTokenNotNil];
    [self assertScopesReturned:expectedScopes];

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *homeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(homeAccountId);

    if (testAccount)
    {
        NSDictionary *result = [self resultDictionary];
        NSString *resultTenantId = result[@"tenantId"];
        XCTAssertEqualObjects(resultTenantId, testAccount.targetTenantId);
        XCTAssertEqualObjects(homeAccountId, testAccount.homeAccountId);
    }

    [self closeResultView];
    return homeAccountId;
}

- (void)runSharedSilentAADLoginWithClientId:(NSString *)clientId
                                     scopes:(NSString *)scopes
                       expectedResultScopes:(NSArray *)expectedScopes
                            silentAuthority:(NSString *)silentAuthority
                             cacheAuthority:(NSString *)cacheAuthority
                          accountIdentifier:(NSString *)accountIdentifier
                          validateAuthority:(BOOL)validateAuthority
                            expectedAccount:(MSIDTestAccount *)testAccount
{
    NSDictionary *config = [self configDictionaryWithClientId:clientId
                                                       scopes:scopes
                                                  redirectUri:nil
                                                    authority:silentAuthority
                                                   uiBehavior:nil
                                                    loginHint:nil
                                            validateAuthority:validateAuthority
                                           useEmbeddedWebView:NO
                                      useSafariViewController:NO
                                            accountIdentifier:accountIdentifier];
    // Acquire token silently
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    NSMutableDictionary *mutableConfig = [config mutableCopy];

    // The developer provided authority is not necessarily the authority that MSAL does cache lookups with
    // Therefore, authority used to expire access token might be different
    if (cacheAuthority) mutableConfig[@"authority"] = cacheAuthority;

    // Now expire access token
    [self expireAccessToken:mutableConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now lookup access token without authority
    [mutableConfig removeObjectForKey:@"authority"];
    [self acquireTokenSilent:mutableConfig];
    [self assertAccessTokenNotNil];

    if (testAccount)
    {
        NSDictionary *result = [self resultDictionary];
        XCTAssertEqualObjects(result[@"tenantId"], testAccount.targetTenantId);
        XCTAssertEqualObjects(result[@"user"][@"home_account_id"], testAccount.homeAccountId);
    }

    [self assertScopesReturned:expectedScopes];
    [self closeResultView];
}

- (void)runSharedAuthUIAppearsStepWithClientId:(NSString *)clientId
                                        scopes:(NSString *)scopes
                                   redirectUri:(NSString *)redirectUri
                                     authority:(NSString *)authority
                                    uiBehavior:(NSString *)uiBehavior
                                     loginHint:(NSString *)loginHint
                             accountIdentifier:(NSString *)accountIdentifier
                             validateAuthority:(BOOL)validateAuthority
                            useEmbeddedWebView:(BOOL)useEmbedded
                       useSafariViewController:(BOOL)useSFController
{
    NSDictionary *config = [self configDictionaryWithClientId:clientId
                                                       scopes:scopes
                                                  redirectUri:redirectUri
                                                    authority:authority
                                                   uiBehavior:uiBehavior
                                                    loginHint:loginHint
                                            validateAuthority:validateAuthority
                                           useEmbeddedWebView:useEmbedded
                                      useSafariViewController:useSFController
                                            accountIdentifier:accountIdentifier];
    [self acquireToken:config];

    if (!useSFController
        && !useEmbedded)
    {
        [self allowSFAuthenticationSessionAlert];
    }

    [self assertAuthUIAppearWithEmbedded:useEmbedded safariViewController:useSFController];
    [self closeAuthUIWithEmbedded:useEmbedded safariViewController:useSFController];
    [self assertErrorCode:@"MSALErrorUserCanceled"];
    [self closeResultView];
}

@end
