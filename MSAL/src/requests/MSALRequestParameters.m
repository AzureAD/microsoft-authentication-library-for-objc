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

#import "MSALRequestParameters.h"
#import "MSALUIBehavior.h"
#import "MSALError_Internal.h"
#import "MSIDConfiguration.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAuthorityFactory.h"
#import "MSALAuthority.h"
#import "MSIDConstants.h"

@implementation MSALRequestParameters

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        [self initDefaultAppMetadata];
    }

    return self;
}

- (void)initDefaultAppMetadata
{
    NSDictionary *metadata = [[NSBundle mainBundle] infoDictionary];

    NSString *appName = metadata[@"CFBundleDisplayName"];

    if (!appName)
    {
        appName = metadata[@"CFBundleName"];
    }

    NSString *appVer = metadata[@"CFBundleShortVersionString"];

    _appRequestMetadata = @{MSID_VERSION_KEY: @MSAL_VERSION_STRING,
                            MSID_APP_NAME_KEY: appName ? appName : @"",
                            MSID_APP_VER_KEY: appVer ? appVer : @""};
}

- (void)setScopesFromArray:(NSArray<NSString *> *)scopes
{
    NSMutableArray *scopesLowercase = [NSMutableArray new];
    for (NSString *scope in scopes)
    {
        [scopesLowercase addObject:scope.lowercaseString];
    }
    self.scopes = [[NSOrderedSet alloc] initWithArray:scopesLowercase copyItems:YES];
}

- (MSIDConfiguration *)msidConfiguration
{
    MSIDAuthority *authority = self.cloudAuthority ? self.cloudAuthority : self.unvalidatedAuthority;

    MSIDConfiguration *config = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                 redirectUri:self.redirectUri
                                                                    clientId:self.clientId
                                                                      target:self.scopes.msidToString];

    return config;
}

- (void)setCloudAuthorityWithCloudHostName:(NSString *)cloudHostName
{
    if ([NSString msidIsStringNilOrBlank:cloudHostName]) return;

    NSURL *cloudAuthority = [self.unvalidatedAuthority.url msidAuthorityWithCloudInstanceHostname:cloudHostName];
    _cloudAuthority = [[MSIDAuthorityFactory new] authorityFromUrl:cloudAuthority context:nil error:nil];
}

@end
