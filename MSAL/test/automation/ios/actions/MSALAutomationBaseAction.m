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
#import "MSALAuthorityFactory.h"
#import "MSIDAutomationTestRequest.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAutomationTestResult.h"
#import "MSALResult+Automation.h"

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
        authority = [MSALAuthorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    }

    MSALPublicClientApplication *clientApplication =
    [[MSALPublicClientApplication alloc] initWithClientId:parameters.clientId
                                                authority:authority
                                              redirectUri:parameters.redirectUri
                                                    error:error];

    clientApplication.validateAuthority = validateAuthority;
    clientApplication.sliceParameters = parameters.sliceParameters;

    return clientApplication;
}

- (MSALAccount *)accountWithParameters:(MSIDAutomationTestRequest *)parameters
                           application:(MSALPublicClientApplication *)application
                                 error:(NSError **)error
{
    NSString *accountIdentifier = parameters.homeAccountIdentifier;

    if (accountIdentifier)
    {
        return [application accountForHomeAccountId:accountIdentifier error:error];
    }
    else if (parameters.legacyAccountIdentifier)
    {
        return [application accountForUsername:parameters.legacyAccountIdentifier error:error];
    }

    return nil;
}

- (MSIDAutomationTestResult *)testResultWithMSALError:(NSError *)error
{
    NSString *errorString = [NSString stringWithFormat:@"Error Domain=%@ Code=%ld Description=%@", error.domain, (long)error.code, error.localizedDescription];

    NSMutableDictionary *errorDictionary = [NSMutableDictionary new];
    errorDictionary[@"error_title"] = errorString;

    if ([error.domain isEqualToString:MSALErrorDomain])
    {
        errorDictionary[@"error_code"] = MSALStringForErrorCode(error.code);
        errorDictionary[@"error_description"] = error.userInfo[MSALErrorDescriptionKey];

        if (error.userInfo[MSALOAuthSubErrorKey])
        {
            errorDictionary[@"subcode"] = error.userInfo[MSALOAuthSubErrorKey];
        }

        if (error.userInfo[NSUnderlyingErrorKey])
        {
            errorDictionary[@"underlying_error"] = [error.userInfo[NSUnderlyingErrorKey] description];
        }

        NSMutableDictionary *userInfo = [error.userInfo mutableCopy];
        [userInfo removeObjectForKey:NSUnderlyingErrorKey];
        [userInfo removeObjectForKey:MSALInvalidResultKey];

        errorDictionary[@"user_info"] = userInfo;
    }
    else if ([error.domain isEqualToString:MSIDErrorDomain])
    {
        @throw @"MSID errors should never be seen in MSAL";
    }

    MSIDAutomationTestResult *result = [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier success:NO additionalInfo:errorDictionary];

    return result;
}

- (MSIDAutomationTestResult *)testResultWithMSALResult:(MSALResult *)msalResult error:(NSError *)error
{
    if (error)
    {
        return [self testResultWithMSALError:error];
    }

    NSDictionary *resultDictionary = [msalResult itemAsDictionary];
    return [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier success:YES additionalInfo:resultDictionary];
}

@end
