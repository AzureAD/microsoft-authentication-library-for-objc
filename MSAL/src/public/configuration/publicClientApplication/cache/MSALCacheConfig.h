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

/**
 MSAL configuration interface responsible for token caching and keychain configuration.
 */
@interface MSALCacheConfig : NSObject <NSCopying>

#pragma mark - Configure keychain sharing

/**
    The keychain sharing group to use for the token cache.
    The default value is `com.microsoft.adalcache` for iOS and `com.microsoft.identity.universalstorage` for macOS and it needs to be declared in your application's entitlements.
    See more https://developer.apple.com/documentation/security/keychain_services/keychain_items/sharing_access_to_keychain_items_among_a_collection_of_apps?language=objc
    @note To disable keychain sharing, set this to your bundleIdentifier using [[NSBundle mainBundle] bundleIdentifier]. MSAL will then use your private keychain group, which is available only to your application.
 */
@property NSString *keychainSharingGroup;

/**
    Retrieve default MSAL keychain access group.
    The default value is `com.microsoft.adalcache` for iOS and `com.microsoft.identity.universalstorage` for macOS
 */
+ (NSString *)defaultKeychainSharingGroup;

#pragma mark - Extend MSAL account cache

/**
    List of external account storage providers that helps you to combine your own accounts with MSAL accounts and use a consistent API for the account management and enumeration.
    Each external account provider is responsible for retrieving, enumerating, updating and removing external accounts.
    Some examples where this might be useful:
    1.  An app is migrating from ADAL to MSAL. Because ADAL didn't support account enumeration, developer built a separate layer to store ADAL accounts in the app.
        MSAL provides account enumeration built-in. Using this API, application can let MSAL combine multiple sources of accounts and operate on a single source.
    2.  An app duplicates MSAL accounts in its own account storage with some additional app specific data.
        Every time when MSAL retrieves/updates an account, application wants to synchronize that account into its own account store.
 */
@property (nonatomic, readonly) NSArray<id<MSALExternalAccountProviding>> *externalAccountProviders;

/**
    Adds a new external account storage provider to be used by MSAL in account retrieval.
    @note This operation is not thread safe.
 */
- (void)addExternalAccountProvider:(id<MSALExternalAccountProviding>)externalAccountProvider;

#if !TARGET_OS_IPHONE

#pragma mark - Configure macOS cache

/**
    Backward compatible ADAL serialized cache provider.
    Use it if you were serializing ADAL cache on macOS and want to have backward compatibility with macOS apps.
 */
@property (nonatomic, nullable) MSALSerializedADALCacheProvider *serializedADALCache;

/**
    Array of SecTrustedApplicationsRef that is allowed to access the keychain elements
    created by the keychain cache.
 */
@property (readonly, nonnull) NSArray *trustedApplications;

/**
    Creates a list of trusted app instances (SecTrustedApplicationsRef) based on the apps at the given path in the file system.
 */
- (NSArray *)createTrustedApplicationListFromPaths:(NSArray<NSString *> *)appPaths error:(NSError * _Nullable __autoreleasing * _Nullable)error;

#endif

#pragma mark - Unavailable initializers

/**
    Use instance of MSALCacheConfig in the `MSALPublicClientApplicationConfig` instead.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
   Use instance of MSALCacheConfig in the `MSALPublicClientApplicationConfig` instead.
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
