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

#import "MSALPublicClientApplicationConfig+Internal.h"
#import "MSALRedirectUri.h"
#import "MSALAADAuthority.h"
#import "MSALExtraQueryParameters.h"
#import "MSALSliceConfig.h"

@implementation MSALPublicClientApplicationConfig
{
    MSALSliceConfig *_sliceConfig;
}



static NSString *const s_defaultAuthorityUrlString = @"https://login.microsoftonline.com/common";

- (instancetype)initWithClientId:(NSString *)clientId
{
    self = [super init];
    if (self)
    {
        _clientId = clientId;
        NSURL *authorityURL = [NSURL URLWithString:s_defaultAuthorityUrlString];
        _authority = [[MSALAADAuthority alloc] initWithURL:authorityURL error:nil];
        
        _extraQueryParameters = [[MSALExtraQueryParameters alloc] init];
    }
    
    return self;
}

- (instancetype)initWithClientId:(NSString *)clientId redirectUri:(NSString *)redirectUri
{
    self = [self initWithClientId:clientId];
    if (self)
    {
        _redirecrUri = redirectUri;
    }
    
    return self;
}

- (void)setSliceConfig:(MSALSliceConfig *)sliceConfig
{
    _sliceConfig = sliceConfig;

    if (sliceConfig)
    {
        _extraQueryParameters.extraURLQueryParameters[@"slice"] = sliceConfig.slice;
        _extraQueryParameters.extraURLQueryParameters[@"dc"] = sliceConfig.dc;
    }
    else
    {
        [_extraQueryParameters.extraURLQueryParameters removeObjectForKey:@"slice"];
        [_extraQueryParameters.extraURLQueryParameters removeObjectForKey:@"dc"];
    }
}

- (MSALSliceConfig *)sliceConfig
{
    return _sliceConfig;
}

@end
