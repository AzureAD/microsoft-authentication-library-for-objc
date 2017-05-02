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
#import "MSALAuthority.h"

#define MSAL_APP_SETTINGS_KEY @"MSALSettings"

#define MSAL_APP_SCOPE_USER_READ        @"User.Read"

NSString* MSALTestAppCacheChangeNotification = @"MSALTestAppCacheChangeNotification";

static NSArray<NSString *> *s_authorities = nil;

static NSArray<NSString *> *s_scopes_available = nil;

@interface MSALTestAppSettings()
{
    NSMutableSet <NSString *> *_scopes;
}

@end

@implementation MSALTestAppSettings

+ (void)initialize
{
    NSMutableArray<NSString *> *authorities = [NSMutableArray new];
    
    NSSet<NSString *> *trustedHosts = [MSALAuthority trustedHosts];
    for (NSString *host in trustedHosts)
    {
        [authorities addObject:[NSString stringWithFormat:@"https://%@/common", host]];
    }
    
    s_authorities = authorities;
    
    s_scopes_available = @[MSAL_APP_SCOPE_USER_READ, @"Tasks.Read"];

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

+ (NSArray<NSString *> *)authorities
{
    return s_authorities;
}

- (MSALUser *)userForUserIdentifier:(NSString *)userIdentifier
{
    if (!userIdentifier)
    {
        return nil;
    }
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:TEST_APP_CLIENT_ID
                                                authority:_authority
                                                    error:&error];
    if (application == nil)
    {
        LOG_ERROR(nil, @"failed to create application to get user: %@", error);
        return nil;
    }
    
    NSArray<MSALUser *> *users = [application users:nil];
    if (!users)
    {
        LOG_ERROR(nil, @"no users came back from the application");
        return nil;
    }
    
    for (MSALUser *user in users)
    {
        if ([userIdentifier isEqualToString:user.userIdentifier])
        {
            return user;
        }
    }
    
    LOG_WARN(nil, @"failed to find user identifier \"%@\" among users.", userIdentifier);
    return nil;
}

- (void)readFromDefaults
{
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:MSAL_APP_SETTINGS_KEY];
    if (!settings)
    {
        return;
    }
    
    _authority = [settings objectForKey:@"authority"];
    _loginHint = [settings objectForKey:@"loginHint"];
    NSNumber* validate = [settings objectForKey:@"validateAuthority"];
    _validateAuthority = validate ? [validate boolValue] : YES;
    _currentUser = [self userForUserIdentifier:[settings objectForKey:@"currentUser"]];
    
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

- (void)setAuthority:(NSString *)authority
{
    [self setValue:authority forKey:@"authority"];
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

- (void)setCurrentUser:(MSALUser *)currentUser
{
    [self setValue:currentUser.userIdentifier
            forKey:@"currentUser"];
    _currentUser = currentUser;
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


@end
