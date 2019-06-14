//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALAutomationBaseAction.h"
#import <MSAL/MSAL.h>
#import "MSIDAutomationTestRequest.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAutomationTestResult.h"
#import "MSALResult+Automation.h"
#import "MSIDAutomationErrorResult.h"
#import "MSIDAutomationSuccessResult.h"
#import "MSALAccount.h"
#import "MSALAccount+Internal.h"
#import "MSALTenantProfile.h"
#import "MSALSliceConfig.h"

@implementation MSALAutomationBaseAction

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        self.legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil];
        self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:@[self.legacyAccessor]];
        self.accountCredentialCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    }

    return self;
}

#pragma mark - MSIDAutomationTestAction

- (NSString *)actionIdentifier
{
    return @"base_action";
}

- (BOOL)needsRequestParameters
{
    return NO;
}

- (void)performActionWithParameters:(MSIDAutomationTestRequest *)parameters
                containerController:(MSIDAutomationMainViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSAssert(NO, @"Abstract method, it should never be called!");
}

#pragma mark - Helpers

- (MSALPublicClientApplication *)applicationWithParameters:(MSIDAutomationTestRequest *)parameters
                                                     error:(NSError **)error
{
    BOOL validateAuthority = parameters.validateAuthority;

    MSALAuthority *authority = nil;

    if (parameters.configurationAuthority)
    {
        NSURL *authorityUrl = [[NSURL alloc] initWithString:parameters.configurationAuthority];
        authority = [MSALAuthority authorityWithURL:authorityUrl error:nil];
    }
    
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:parameters.clientId
                                                                                                redirectUri:parameters.redirectUri
                                                                                                  authority:authority];
    
    if (!validateAuthority)
    {
        config.knownAuthorities = @[config.authority];
    }
    
    config.sliceConfig = [[MSALSliceConfig alloc] initWithSlice:parameters.sliceParameters[@"slice"] dc:parameters.sliceParameters[@"dc"]];
    
    MSALPublicClientApplication *clientApplication = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:error];
  
    return clientApplication;
}

- (MSALAccount *)accountWithParameters:(MSIDAutomationTestRequest *)parameters
                           application:(MSALPublicClientApplication *)application
                                 error:(NSError **)error
{
    NSString *accountIdentifier = parameters.homeAccountIdentifier;

    if (accountIdentifier)
    {
        return [application accountForIdentifier:accountIdentifier error:error];
    }
    else if (parameters.legacyAccountIdentifier)
    {
        return [application accountForUsername:parameters.legacyAccountIdentifier error:error];
    }
        
    return nil;
}

- (MSIDAutomationTestResult *)testResultWithMSALError:(NSError *)error
{
    return [[MSIDAutomationErrorResult alloc] initWithAction:self.actionIdentifier
                                                       error:error
                                              additionalInfo:nil];
}

- (MSIDAutomationTestResult *)testResultWithMSALResult:(MSALResult *)msalResult error:(NSError *)error
{
    if (error)
    {
        return [self testResultWithMSALError:error];
    }

    NSString *scopeString = [msalResult.scopes componentsJoinedByString:@" "];
    NSInteger expiresOn = [msalResult.expiresOn timeIntervalSince1970];

    MSIDAutomationUserInformation *userInfo = [MSIDAutomationUserInformation new];
    userInfo.objectId = msalResult.tenantProfile.claims[@"oid"];
    userInfo.tenantId = msalResult.tenantProfile.tenantId;
    userInfo.username = msalResult.account.username;
    userInfo.homeAccountId = msalResult.account.homeAccountId.identifier;
    userInfo.localAccountId = msalResult.tenantProfile.identifier;
    userInfo.homeObjectId = msalResult.account.homeAccountId.objectId;
    userInfo.homeTenantId = msalResult.account.homeAccountId.tenantId;
    userInfo.environment = msalResult.account.environment;

    MSIDAutomationTestResult *result = [[MSIDAutomationSuccessResult alloc] initWithAction:self.actionIdentifier
                                                                               accessToken:msalResult.accessToken
                                                                              refreshToken:@""
                                                                                   idToken:msalResult.idToken
                                                                                 authority:msalResult.authority.url.absoluteString
                                                                                    target:scopeString
                                                                             expiresOnDate:expiresOn
                                                                                    isMRRT:YES
                                                                           userInformation:userInfo
                                                                            additionalInfo:nil];

    return result;
}

@end
