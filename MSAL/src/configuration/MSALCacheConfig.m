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


#import "MSALCacheConfig.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#else
#import "MSIDMacKeychainTokenCache.h"
#endif

@interface MSALCacheConfig()

@property (nonatomic, readwrite) NSArray<id<MSALExternalAccountProviding>> *externalAccountProviders;

@end

@implementation MSALCacheConfig
  
- (instancetype)initWithKeychainSharingGroup:(NSString *)keychainSharingGroup
{
    self = [super init];
    if (self)
    {
        _keychainSharingGroup = keychainSharingGroup;
    }
    return self;
}

+ (NSString *)defaultKeychainSharingGroup
{
#if TARGET_OS_IPHONE
    return MSIDKeychainTokenCache.defaultKeychainGroup;
#else
    return MSIDMacKeychainTokenCache.defaultKeychainGroup;
#endif
}

+ (instancetype)defaultConfig
{
    return [[self.class alloc] initWithKeychainSharingGroup:self.defaultKeychainSharingGroup];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSString *keychainSharingGroup = [_keychainSharingGroup copyWithZone:zone];
    MSALCacheConfig *copiedConfig = [[self.class alloc] initWithKeychainSharingGroup:keychainSharingGroup];
    copiedConfig->_externalAccountProviders = [[NSArray alloc] initWithArray:_externalAccountProviders copyItems:NO];
#if !TARGET_OS_IPHONE
    copiedConfig->_serializedADALCache = _serializedADALCache;
#endif
    return copiedConfig;
}

- (void)addExternalAccountProvider:(id<MSALExternalAccountProviding>)externalAccountProvider
{
    if (!externalAccountProvider)
    {
        return;
    }
    
    NSMutableArray *newExternalProviders = [NSMutableArray new];
    [newExternalProviders addObjectsFromArray:self.externalAccountProviders];
    [newExternalProviders addObject:externalAccountProvider];
    self.externalAccountProviders = newExternalProviders;
}

@end
