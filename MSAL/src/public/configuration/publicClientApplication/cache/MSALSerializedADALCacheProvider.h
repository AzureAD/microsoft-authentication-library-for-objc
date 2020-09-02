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

NS_ASSUME_NONNULL_BEGIN

@class MSALSerializedADALCacheProvider;

/**
    Class implementing MSALSerializedADALCacheProviderDelegate is responsible for persistence and management of ADAL cache on macOS
 */

@protocol MSALSerializedADALCacheProviderDelegate <NSObject>

/**
    This delegate method will be called before performing a cache lookup operation.
    The delegate implementation should ensure that latest cache is loaded from disk to the in-memory representation of ADAL cache (MSALSerializedADALCacheProvider) at this point
 */
- (void)willAccessCache:(nonnull MSALSerializedADALCacheProvider *)cache;

/**
    This delegate method will be called after performing a cache lookup operation.
 */
- (void)didAccessCache:(nonnull MSALSerializedADALCacheProvider *)cache;

/**
    This delegate method will be called before performing a cache write operation.
    The delegate implementation should ensure that latest cache is loaded from disk to the in-memory representation of ADAL cache (MSALSerializedADALCacheProvider) at this point.
*/
- (void)willWriteCache:(nonnull MSALSerializedADALCacheProvider *)cache;

/**
    This delegate method will be called after performing a cache update operation.
    The delegate implementation should serialize and write the latest in-memory representation of ADAL cache to disk at this point.
*/
- (void)didWriteCache:(nonnull MSALSerializedADALCacheProvider *)cache;

@end

/**
    Representation of ADAL serialized cache.
    Use it to achieve SSO or migration scenarios between ADAL Objective-C for macOS and MSAL for macOS
 */

@interface MSALSerializedADALCacheProvider : NSObject <NSCopying>

#pragma mark - Getting a class implementing MSALSerializedADALCacheProviderDelegate

/**
    Delegate of MSALSerializedADALCacheProvider is responsible for storing and reading serialized ADAL cache to the disk (e.g. keychain).
 */
@property (nonatomic, nonnull, readonly) id<MSALSerializedADALCacheProviderDelegate> delegate;

#pragma mark - Data serialization

/**
    Serializes current in-memory representation of ADAL cache into NSData
    @param error                                Error if present
 */
- (nullable NSData *)serializeDataWithError:(NSError * _Nullable * _Nullable)error;

/**
    Deserializes NSData into in-memory representation of ADAL cache
    @param serializedData             Serialized ADAL cache
    @param error                                 Error if present
*/
- (BOOL)deserialize:(nonnull NSData *)serializedData error:(NSError * _Nullable * _Nullable)error;

#pragma mark - Configure MSALSerializedADALCacheProvider

/**
    Initializes MSALSerializedADALCacheProvider with a delegate.
    @param delegate                         Class implementing MSALSerializedADALCacheProviderDelegate protocol that is responsible for persistence and management of ADAL cache
    @param error                                Error if present
 */
- (nullable instancetype)initWithDelegate:(nonnull id<MSALSerializedADALCacheProviderDelegate>)delegate
                                    error:(NSError * _Nullable * _Nullable)error;

#if TARGET_OS_OSX

/**
   Initializes MSALSerializedADALCacheProvider with attributes allowing MSAL to write item into the keychain.
    @param keychainAttributes              All keychain attributes needed to write ADAL cache item (at minimum kSecAttrService and kSecAttrAccount)
    @param trustedApplications            List of apps that the item should be shared with.
    @param accessLabel                              Title for the ADAL cache item access control.
    @param error                                           Error if present
 
    @note By using this initializer, application delegates writing and reading from the keychain to MSAL.
    This might or might not work for all apps. If you have your own implementation of ADAL cache serialization when migrating to MSAL, you should use initWithDelegate:error: initializer and implement your own ADAL cache persistence.
*/
- (nullable instancetype)initWithKeychainAttributes:(nonnull NSDictionary *)keychainAttributes
                                trustedApplications:(nonnull NSArray *)trustedApplications
                                        accessLabel:(nonnull NSString *)accessLabel
                                              error:(NSError * _Nullable * _Nullable)error;

#endif


@end

NS_ASSUME_NONNULL_END
