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
#import "MSALCacheConfig+Internal.h"
#import "MSIDConstants.h"

static double defaultTokenExpirationBuffer = 300; //in seconds, ensures catching of clock differences between the server and the device

@implementation MSALPublicClientApplicationConfig
{
    MSALSliceConfig *_sliceConfig;
}

- (instancetype)initWithClientId:(NSString *)clientId
{
    return [self initWithClientId:clientId redirectUri:nil authority:nil];
}

- (instancetype)initWithClientId:(NSString *)clientId
                     redirectUri:(nullable NSString *)redirectUri
                       authority:(nullable MSALAuthority *)authority
        nestedAuthBrokerClientId:(nullable NSString *)nestedAuthBrokerClientId
     nestedAuthBrokerRedirectUri:(nullable NSString *)nestedAuthBrokerRedirectUri
{
    self = [super init];
    if (self)
    {
        _clientId = clientId;
        _redirectUri = redirectUri;
        _nestedAuthBrokerClientId = nestedAuthBrokerClientId;
        _nestedAuthBrokerRedirectUri = nestedAuthBrokerRedirectUri;
        
        NSURL *authorityURL = [NSURL URLWithString:MSID_DEFAULT_AAD_AUTHORITY];
        
        _authority = authority ?: [[MSALAADAuthority alloc] initWithURL:authorityURL error:nil];
        _extraQueryParameters = [MSALExtraQueryParameters new];
        
        _cacheConfig = [MSALCacheConfig defaultConfig];
        _tokenExpirationBuffer = defaultTokenExpirationBuffer;
    }
    
    return self;
}

- (instancetype)initWithClientId:(NSString *)clientId redirectUri:(nullable NSString *)redirectUri authority:(nullable MSALAuthority *)authority
{
    return [self initWithClientId:clientId
                      redirectUri:redirectUri
                        authority:authority
         nestedAuthBrokerClientId:nil
      nestedAuthBrokerRedirectUri:nil];
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

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSString *clientId = [_clientId copyWithZone:zone];
    MSALPublicClientApplicationConfig *item = [[MSALPublicClientApplicationConfig alloc] initWithClientId:[clientId copy]];
    item->_redirectUri = [_redirectUri copyWithZone:zone];
    item->_authority = [_authority copyWithZone:zone];
    item->_nestedAuthBrokerClientId = [_nestedAuthBrokerClientId copyWithZone:zone];
    item->_nestedAuthBrokerRedirectUri = [_nestedAuthBrokerRedirectUri copyWithZone:zone];
    
    if (_knownAuthorities)
    {
        item->_knownAuthorities = [[NSArray alloc] initWithArray:_knownAuthorities copyItems:YES];
    }
    
    item->_extendedLifetimeEnabled = _extendedLifetimeEnabled;
    
    if (_clientApplicationCapabilities)
    {
        item->_clientApplicationCapabilities = [[NSArray alloc] initWithArray:_clientApplicationCapabilities copyItems:YES];
    }
    
    item->_tokenExpirationBuffer = _tokenExpirationBuffer;
    item->_sliceConfig = [_sliceConfig copyWithZone:zone];
    item->_cacheConfig = [_cacheConfig copyWithZone:zone];
    item->_verifiedRedirectUri = [_verifiedRedirectUri copyWithZone:zone];
    item->_extraQueryParameters = [_extraQueryParameters copyWithZone:zone];
    item->_multipleCloudsSupported = _multipleCloudsSupported;
    return item;
}

@end
