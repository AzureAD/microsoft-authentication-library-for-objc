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

static NSString *const s_defaultAuthorityUrlString = @"https://login.microsoftonline.com/common";

- (instancetype)initWithClientId:(NSString *)clientId
{
    self = [super init];
    if (self)
    {
        self.clientId = clientId;
#if TARGET_OS_IPHONE
        self.webviewType = MSALWebviewTypeDefault;
#else
        self.webviewType = MSALWebviewTypeWKWebView;
#endif
        NSURL *authorityURL = [NSURL URLWithString:s_defaultAuthorityUrlString];
        self.authority = [[MSALAADAuthority alloc] initWithURL:authorityURL error:nil];
        
        self.extraQueryParameters = [[MSALExtraQueryParameters alloc] init];
    }
    
    return self;
}

- (instancetype)initWithClientId:(NSString *)clientId redirectURI:(NSString *)redirectURI
{
    self = [self initWithClientId:clientId];
    if (self)
    {
        _redirecrUri = redirectURI;
    }
    
    return self;
}

- (MSALSliceConfig *)slice { return self.slice; }

- (void)setSlice:(MSALSliceConfig *)slice
{
    if (!slice)
    {
        [self.extraQueryParameters.extraURLQueryParameters removeObjectForKey:@"slice"];
        [self.extraQueryParameters.extraURLQueryParameters removeObjectForKey:@"dc"];
    }
    else
    {
        [self.extraQueryParameters.extraTokenURLParameters setObject:slice.slice forKey:@"slice"];
        [self.extraQueryParameters.extraTokenURLParameters setObject:slice.dc forKey:@"dc"];
    }

    
}

@end
