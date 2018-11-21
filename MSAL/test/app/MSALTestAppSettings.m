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

#import "MSALTestAppSettings.h"
#import "MSIDAuthority.h"
#import "MSALAccountId.h"
#import "MSALAuthorityFactory.h"
#import "MSIDAuthority.h"
#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSALPublicClientApplication.h"
#import "MSALAccount.h"

#if __has_include("MSALAdditionalTestAppSettings.h")
#include "MSALAdditionalTestAppSettings.h"
#else
// If you put a header file at ~/aadoverrides/ADAdditionalTestAppSettings.h with
// function named _addtionalProfiles() that returns an NSDictionary that will
// be folded into the profiles list without you having to constantly alter your
// github enlistment!
static NSDictionary* _additionalProfiles()
{
    return @{
             @"MSAL-TestApp" : @{@"clientId" : @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                            @"redirectUri" :@"msalb6c69a37-df96-4db0-9088-2ab96e1d8215://auth"},
             };
}
#endif

#define MSAL_APP_SETTINGS_KEY @"MSALSettings"

#define MSAL_APP_SCOPE_USER_READ @"User.Read"

NSString* MSALTestAppCacheChangeNotification = @"MSALTestAppCacheChangeNotification";

static NSArray<NSString *> *s_authorities = nil;

static NSArray<NSString *> *s_b2cAuthorities = nil;

static NSArray<NSString *> *s_scopes_available = nil;

static NSArray<NSString *> *s_authorityTypes = nil;

static NSDictionary *s_profiles = nil;

@interface MSALTestAppSettings()
{
    NSMutableSet <NSString *> *_scopes;
}

@end

@implementation MSALTestAppSettings

+ (void)initialize
{
    NSMutableArray<NSString *> *authorities = [NSMutableArray new];
    NSSet<NSString *> *trustedHosts = [MSIDAADNetworkConfiguration.defaultConfiguration trustedHosts];
    
    for (NSString *host in trustedHosts)
    {
        __auto_type tenants = @[@"common", @"organizations", @"consumers"];
        
        for (NSString *tenant in tenants)
        {
            __auto_type authorityString = [NSString stringWithFormat:@"https://%@/%@", host, tenant];
            [authorities addObject:authorityString];
        }
    }
    
    s_authorities = authorities;
    
    s_scopes_available = @[MSAL_APP_SCOPE_USER_READ, @"Tasks.Read", @"https://graph.microsoft.com/.default",@"https://msidlabb2c.onmicrosoft.com/msidlabb2capi/read"];
    
    __auto_type signinPolicyAuthority = @"https://login.microsoftonline.com/tfp/msidlabb2c.onmicrosoft.com/B2C_1_SignInPolicy";
    __auto_type signupPolicyAuthority = @"https://login.microsoftonline.com/tfp/msidlabb2c.onmicrosoft.com/B2C_1_SignUpPolicy";
    __auto_type profilePolicyAuthority = @"https://login.microsoftonline.com/tfp/msidlabb2c.onmicrosoft.com/B2C_1_EditProfilePolicy";
    
    s_b2cAuthorities = @[signinPolicyAuthority, signupPolicyAuthority, profilePolicyAuthority];
    s_authorityTypes = @[@"AAD",@"B2C"];
    s_profiles = _additionalProfiles();
}

+ (MSALTestAppSettings*)settings
{
    static dispatch_once_t s_settingsOnce;
    static MSALTestAppSettings* s_settings = nil;
    
    dispatch_once(&s_settingsOnce,^{
        s_settings = [MSALTestAppSettings new];
        s_settings->_profile = [[s_profiles allValues] objectAtIndex:0];
        [s_settings readFromDefaults];
        s_settings->_scopes = [NSMutableSet new];
    });
    
    return s_settings;
}

+ (NSDictionary *)profiles
{
    return s_profiles;
}

+ (NSArray<NSString *> *)aadAuthorities
{
    return s_authorities;
}

+ (NSArray<NSString *> *)b2cAuthorities
{
    return s_b2cAuthorities;
}

+ (NSArray<NSString *> *)authorityTypes
{
    return s_authorityTypes;
}

- (MSALAccount *)accountForAccountHomeIdentifier:(NSString *)accountIdentifier
{
    if (!accountIdentifier)
    {
        return nil;
    }
    
    NSDictionary *currentProfile = _profile;
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                                                           authority:_authority
                                                                                         redirectUri:redirectUri
                                                                                               error:&error];
    if (application == nil)
    {
        MSID_LOG_ERROR(nil, @"failed to create application to get user: %@", error);
        return nil;
    }
    
    MSALAccount *account = [application accountForHomeAccountId:accountIdentifier error:&error];
    return account;
}

- (void)readFromDefaults
{
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:MSAL_APP_SETTINGS_KEY];
    if (!settings)
    {
        return;
    }
    
    NSDictionary *profile = [settings objectForKey:MSAL_APP_PROFILE];
    if (profile)
    {
        _profile = profile;
    }
    
    NSString *authorityString = [settings objectForKey:@"authority"];
    if (authorityString)
    {
        NSURL *authorityUrl = [[NSURL alloc] initWithString:authorityString];
        __auto_type authority = [MSALAuthorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
        _authority = authority;
    }
    
    _loginHint = [settings objectForKey:@"loginHint"];
    NSNumber* validate = [settings objectForKey:@"validateAuthority"];
    _validateAuthority = validate ? [validate boolValue] : YES;
    _currentAccount = [self accountForAccountHomeIdentifier:[settings objectForKey:@"currentHomeAccountId"]];
}

- (void)setValue:(id)value
          forKey:(nonnull NSString *)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *settings = [[defaults dictionaryForKey:MSAL_APP_SETTINGS_KEY] mutableCopy];
    if (!settings)
    {
        settings = [NSMutableDictionary new];
    }
    
    [settings setValue:value forKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:settings
                                              forKey:MSAL_APP_SETTINGS_KEY];
}

- (void)setAuthority:(MSALAuthority *)authority
{
    [self setValue:authority.msidAuthority.url.absoluteString forKey:@"authority"];
    _authority = authority;
}

- (void)setLoginHint:(NSString *)loginHint
{
    [self setValue:loginHint forKey:@"loginHint"];
    _loginHint = loginHint;
}

- (void)setValidateAuthority:(BOOL)validateAuthority
{
    [self setValue:[NSNumber numberWithBool:validateAuthority]
            forKey:@"validateAuthority"];
    _validateAuthority = validateAuthority;
}

- (void)setCurrentAccount:(MSALAccount *)currentAccount
{
    [self setValue:currentAccount.homeAccountId.identifier forKey:@"currentHomeAccountId"];
    _currentAccount = currentAccount;
}

+ (NSArray<NSString *> *)availableScopes
{
    return s_scopes_available;
}

- (NSSet<NSString *> *)scopes
{
    return _scopes;
}

- (BOOL)addScope:(NSString *)scope
{
    if (![s_scopes_available containsObject:scope])
    {
        return NO;
    }
    
    [_scopes addObject:scope];
    return YES;
}

- (BOOL)removeScope:(NSString *)scope
{
    if (![s_scopes_available containsObject:scope])
    {
        return NO;
    }
    
    [_scopes removeObject:scope];
    return YES;
}

- (void)setProfile:(id)profile
{
    [self setValue:profile forKey:MSAL_APP_PROFILE];
    _profile = profile;
}

@end
