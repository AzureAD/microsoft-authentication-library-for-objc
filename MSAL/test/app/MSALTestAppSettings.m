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
    return nil;
}
#endif

#define MSAL_APP_SETTINGS_KEY @"MSALSettings"

#define MSAL_APP_SCOPE_USER_READ @"User.Read"

NSString* MSALTestAppCacheChangeNotification = @"MSALTestAppCacheChangeNotification";

static NSArray<NSString *> *s_authorities = nil;

static NSArray<NSString *> *s_b2cAuthorities = nil;

static NSArray<NSString *> *s_scopes_available = nil;

static NSArray<NSString *> *s_authorityTypes = nil;

static NSDictionary *s_additionalProfiles = nil;
static NSMutableDictionary *s_profiles = nil;
static NSArray* s_profileTitles = nil;
static NSUInteger s_currentProfileIdx = 0;
static NSDictionary *s_currentProfile = nil;

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
    
    s_scopes_available = @[MSAL_APP_SCOPE_USER_READ, @"Tasks.Read", @"https://graph.microsoft.com/.default",@"https://msidlabb2c.onmicrosoft.com/msidlabb2capi/read", @"TASKS.read"];
    
    __auto_type signinPolicyAuthority = @"https://login.microsoftonline.com/tfp/msidlabb2c.onmicrosoft.com/B2C_1_SignInPolicy";
    __auto_type signupPolicyAuthority = @"https://login.microsoftonline.com/tfp/msidlabb2c.onmicrosoft.com/B2C_1_SignUpPolicy";
    __auto_type profilePolicyAuthority = @"https://login.microsoftonline.com/tfp/msidlabb2c.onmicrosoft.com/B2C_1_EditProfilePolicy";
    
    s_b2cAuthorities = @[signinPolicyAuthority, signupPolicyAuthority, profilePolicyAuthority];
    s_authorityTypes = @[@"AAD",@"B2C"];
    
    
    NSString *defaultKey = @"MSAL-TestApp";
    NSDictionary *defaultValue = @{@"clientId" : @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"redirectUri" :@"msauth.com.microsoft.MSALTestApp://auth"};
    
    s_profiles = [[NSMutableDictionary alloc] initWithObjectsAndKeys:defaultValue, defaultKey, nil];
    s_additionalProfiles = _additionalProfiles();
    [s_profiles addEntriesFromDictionary:s_additionalProfiles];
    
    NSMutableArray *titles = [[NSMutableArray alloc] init];
    [titles addObjectsFromArray:[s_profiles allKeys]];
    
    s_profileTitles = titles;
}

+ (MSALTestAppSettings*)settings
{
    static dispatch_once_t s_settingsOnce;
    static MSALTestAppSettings* s_settings = nil;
    
    dispatch_once(&s_settingsOnce,^{
        s_settings = [MSALTestAppSettings new];
        [s_settings readFromDefaults];
        s_settings->_scopes = [NSMutableSet new];
    });
    
    return s_settings;
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
    
    NSDictionary *currentProfile = [s_profiles objectForKey:[s_profileTitles objectAtIndex:s_currentProfileIdx]];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    
    NSError *error = nil;

    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:_authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];

    if (application == nil)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"failed to create application to get user: %@", error);
        return nil;
    }
    
    MSALAccount *account = [application accountForIdentifier:accountIdentifier error:&error];
    return account;
}

- (void)readFromDefaults
{
    s_currentProfileIdx = 0;
    s_currentProfile = [s_profiles objectForKey:[s_profileTitles objectAtIndex:s_currentProfileIdx]];
    
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:MSAL_APP_SETTINGS_KEY];
    if (!settings)
    {
        return;
    }
    
    NSString* currentProfile = [settings objectForKey:MSAL_APP_PROFILE];
    if (currentProfile)
    {
        s_currentProfileIdx = [s_profileTitles indexOfObject:currentProfile];
        s_currentProfile = [s_profiles objectForKey:[s_profileTitles objectAtIndex:s_currentProfileIdx]];
    }
    
    NSString *authorityString = [settings objectForKey:@"authority"];
    if (authorityString)
    {
        NSURL *authorityUrl = [[NSURL alloc] initWithString:authorityString];
        __auto_type authority = [MSALAuthority authorityWithURL:authorityUrl error:nil];
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
    [self setValue:currentAccount.identifier forKey:@"currentHomeAccountId"];
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

+ (NSDictionary *)profiles
{
    return s_profiles;
}

+ (NSDictionary *)currentProfile
{
    return s_currentProfile;
}

+ (NSString *)currentProfileName
{
    return [s_profileTitles objectAtIndex:s_currentProfileIdx];
}

+ (NSString *)profileTitleForIndex:(NSUInteger)index
{
    return [s_profileTitles objectAtIndex:index];
}

- (void)setCurrentProfile:(NSUInteger)index
{
    s_currentProfileIdx = index;
    NSString *profileName = [s_profileTitles objectAtIndex:index];
    s_currentProfile = [s_profiles objectForKey:profileName];
    [self setValue:profileName forKey:MSAL_APP_PROFILE];
}


@end
