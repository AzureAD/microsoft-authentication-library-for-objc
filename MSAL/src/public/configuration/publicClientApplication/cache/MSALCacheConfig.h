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

#import <Foundation/Foundation.h>

@protocol MSALExternalAccountProviding;
@class MSALSerializedADALCacheProvider;

NS_ASSUME_NONNULL_BEGIN

@interface MSALCacheConfig : NSObject <NSCopying>

/*!
    The keychain sharing group to use for the token cache.
    The default value is com.microsoft.adalcache and it needs to be declared in your application's entitlements.
    See more https://developer.apple.com/documentation/security/keychain_services/keychain_items/sharing_access_to_keychain_items_among_a_collection_of_apps?language=objc
 */
@property NSString *keychainSharingGroup;

/*!
    List of external account stotage providers that helps you to combine your own accounts with MSAL accounts and use a consistent API for the account management and enumeration.
    Each external account provider is responsible for retrieving, enumerating, updating and removing external accounts.
    Some examples where this might be useful:
    1.  An app is migrating from ADAL to MSAL. Because ADAL didn't support account enumeration, developer built a separate layer to store ADAL accounts in the app.
        MSAL provides account enumeration built-in. Using this API, application can let MSAL combine multiple sources of accounts and operate on a single source.
    2.  An app duplicates MSAL accounts in its own account storage with some additional app specific data.
        Every time when MSAL retrieves/updates an account, application wants to synchronize that account into its own account store.
 */
@property (nonatomic, readonly) NSArray<id<MSALExternalAccountProviding>> *externalAccountProviders;

#if !TARGET_OS_IPHONE
/*!
    Backward compatible ADAL serialized cache provider.
    Use it if you were serializing ADAL cache on macOS and want to have backward compatibility with macOS apps.
 */
@property (nonatomic, nullable) MSALSerializedADALCacheProvider *serializedADALCache;

#endif

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new NS_UNAVAILABLE;

+ (NSString *)defaultKeychainSharingGroup;

/*!
    Adds a new external account storage provider to be used by MSAL in account retrieval.
    This operation is not thread safe.
 */
- (void)addExternalAccountProvider:(id<MSALExternalAccountProviding>)externalAccountProvider;

@end

NS_ASSUME_NONNULL_END
