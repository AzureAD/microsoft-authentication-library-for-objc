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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import <Foundation/Foundation.h>
#import "MSALDevicePopManagerUtil.h"
#import "MSIDDevicePopManager.h"
#import "MSIDCacheConfig.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDDevicePopManager.h"
#import "MSIDCacheConfig.h"
#import "MSIDAssymetricKeyKeychainGenerator.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDAssymetricKeyPair.h"
#if !TARGET_OS_IPHONE
#import "MSIDAssymetricKeyLoginKeychainGenerator.h"
#endif
#import "MSIDConstants.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSALCacheConfig.h"
#import "MSIDMacACLKeychainAccessor.h"
@implementation MSALDevicePopManagerUtil

+ (MSIDDevicePopManager *)test_initWithValidCacheConfig
{
    MSIDDevicePopManager *manager;
    MSIDCacheConfig *msidCacheConfig;
    MSIDAssymetricKeyLookupAttributes *keyPairAttributes;
    
#if TARGET_OS_IPHONE
    
    msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:[MSALCacheConfig defaultKeychainSharingGroup]];
    keyPairAttributes = [MSIDAssymetricKeyLookupAttributes new];
    
#else
    keyPairAttributes = [[MSIDAssymetricKeyLookupAttributes alloc] init];

    msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:[MSIDKeychainTokenCache defaultKeychainGroup]];
#endif
    keyPairAttributes.privateKeyIdentifier = MSID_POP_TOKEN_PRIVATE_KEY;
    keyPairAttributes.keyDisplayableLabel = MSID_POP_TOKEN_KEY_LABEL;
    
    manager = [[MSIDDevicePopManager alloc] initWithCacheConfig:msidCacheConfig keyPairAttributes:keyPairAttributes];
    [manager setValue:[MSALDevicePopManagerUtil keyGeneratorWithConfig:msidCacheConfig] forKey:@"keyGeneratorFactory"];
    return manager;
}

+ (MSIDAssymetricKeyKeychainGenerator *)keyGeneratorWithConfig:(MSIDCacheConfig *)cacheConfig
{
#if TARGET_OS_IPHONE
    return [[MSIDAssymetricKeyKeychainGenerator alloc] initWithGroup:cacheConfig.keychainGroup error:nil];
#else
    MSIDMacACLKeychainAccessor *keychainAccessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"Access Control List" error:nil];;
    return [[MSIDAssymetricKeyLoginKeychainGenerator alloc] initWithKeychainGroup:cacheConfig.keychainGroup accessRef:(__bridge SecAccessRef _Nullable)(keychainAccessor.accessControlForNonSharedItems) error:nil];
#endif
}
@end
