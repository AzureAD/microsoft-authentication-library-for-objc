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
static NSDictionary* s_additionalProfiles = nil;


NSString* MSALTestAppCacheChangeNotification = @"MSALTestAppCacheChangeNotification";

static NSDictionary* s_profiles = nil;
static NSArray* s_profileTitles = nil;
static NSUInteger s_currentProfileIdx = 0;

@implementation MSALTestAppSettings
{
    NSDictionary* _settings;
}

+ (void)initialize
{
    s_profiles =
    @{ @"Test App"    : @{ @"authority" : @"https://login.microsoftonline.com/common",
                           // NOTE: The settings below should come from your registered application on
                           //       the azure management portal.
                           //@"clientId" : @"42e42992-6600-4d12-967a-150b3f0bde2d",
                           @"clientId" : @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc", }
       };
    
    s_additionalProfiles = _additionalProfiles();
    
    NSMutableArray* titles = [[NSMutableArray alloc] initWithCapacity:[s_profiles count] + [s_additionalProfiles count]];
    
    for (NSString* profileTitle in s_profiles)
    {
        [titles addObject:profileTitle];
    }
    
    for (NSString* profileTitle in s_additionalProfiles)
    {
        [titles addObject:profileTitle];
    }
    
    [titles sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    s_profileTitles = titles;
    
    NSString* currentProfile = [[NSUserDefaults standardUserDefaults] stringForKey:@"CurrentProfile"];
    if (!currentProfile)
    {
        currentProfile = @"Test App";
    }
    s_currentProfileIdx = [s_profileTitles indexOfObject:currentProfile];
    if (s_currentProfileIdx == NSNotFound)
    {
        s_currentProfileIdx = [s_profileTitles indexOfObject:@"Test App"];
    }
    if (s_currentProfileIdx == NSNotFound)
    {
        s_currentProfileIdx = 0;
    }
}

+ (NSUInteger)numberOfProfiles;
{
    return [s_profileTitles count];
}

+ (NSString*)profileTitleForIndex:(NSUInteger)idx
{
    return [s_profileTitles objectAtIndex:idx];
}

+ (NSString*)currentProfileTitle
{
    return [s_profileTitles objectAtIndex:s_currentProfileIdx];
}

+ (NSUInteger)currentProfileIdx
{
    return s_currentProfileIdx;
}

+ (MSALTestAppSettings*)settings
{
    static dispatch_once_t s_settingsOnce;
    static MSALTestAppSettings* s_settings = nil;
    
    dispatch_once(&s_settingsOnce,^{ s_settings = [MSALTestAppSettings new]; });
    
    return s_settings;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    [self setProfileFromIndex:[MSALTestAppSettings currentProfileIdx]];
    
    return self;
}

- (void)setProfileFromIndex:(NSInteger)idx
{
    NSString* title = [s_profileTitles objectAtIndex:idx];
    s_currentProfileIdx = idx;
    [[NSUserDefaults standardUserDefaults] setObject:title forKey:@"CurrentProfile"];
    NSDictionary* settings = [s_additionalProfiles objectForKey:title];
    if (!settings)
    {
        settings = [s_profiles objectForKey:title];
    }
    
    self.authority = [settings objectForKey:@"authority"];
    self.clientId = [settings objectForKey:@"clientId"];
    self.redirectUri = [NSURL URLWithString:[settings objectForKey:@"redirectUri"]];
    self.defaultUser = [settings objectForKey:@"defaultUser"];
    NSNumber* validate = [settings objectForKey:@"validateAuthority"];
    self.validateAuthority = validate ? [validate boolValue] : YES;
    NSNumber* enableBroker = [settings objectForKey:@"enableBroker"];
    self.enableBroker = [enableBroker boolValue];
}

@end
