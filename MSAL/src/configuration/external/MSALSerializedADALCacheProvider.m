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

#import "MSALSerializedADALCacheProvider.h"
#import "MSIDMacTokenCache.h"
#import "MSALErrorConverter.h"
#import "MSALSerializedADALCacheProvider+Internal.h"
#if TARGET_OS_OSX
#import "MSIDMacLegacyCachePersistenceHandler.h"
#endif

@interface MSALSerializedADALCacheProvider() <MSIDMacTokenCacheDelegate>

@property (nonatomic, nonnull, readwrite) id<MSALSerializedADALCacheProviderDelegate> delegate;
@property (nonatomic, readwrite) MSIDMacTokenCache *macTokenCache;
#if TARGET_OS_OSX
@property (nonatomic, readwrite) MSIDMacLegacyCachePersistenceHandler *cachePersistenceHandler;
#endif

@end

@implementation MSALSerializedADALCacheProvider

- (instancetype)initWithDelegate:(id<MSALSerializedADALCacheProviderDelegate>)delegate
                           error:(__unused NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _delegate = delegate;
        
        // Init datasource.
        _macTokenCache = [MSIDMacTokenCache new];
        _macTokenCache.delegate = self;
    }
    
    return self;
}

#if TARGET_OS_OSX

- (nullable instancetype)initWithKeychainAttributes:(nonnull NSDictionary *)keychainAttributes
                                trustedApplications:(nonnull NSArray *)trustedApplications
                                        accessLabel:(nonnull NSString *)accessLabel
                                              error:(NSError * _Nullable * _Nullable)error
{
    self = [super init];
    
    if (self)
    {
        NSError *msidError = nil;
        MSIDMacLegacyCachePersistenceHandler *persistenceHandler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:trustedApplications
                                                                                                                                 accessLabel:accessLabel
                                                                                                                                  attributes:keychainAttributes
                                                                                                                                       error:&msidError];
        
        if (!persistenceHandler)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to initialize persistent ADAL cache handler");
            
            if (error)
            {
                *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
            }
            
            return nil;
        }
        
        _cachePersistenceHandler = persistenceHandler;
        _macTokenCache = [MSIDMacTokenCache new];
        _macTokenCache.delegate = persistenceHandler;
    }
    
    return self;
}

#endif

- (nullable NSData *)serializeDataWithError:(__unused NSError **)error
{
    // TODO: error.
    return [self.macTokenCache serialize];
}

- (BOOL)deserialize:(nonnull NSData *)serializedData error:(NSError **)error
{
    return [self.macTokenCache deserialize:serializedData error:error];
}

#pragma mark - NSCopying

- (id)copyWithZone:(__unused NSZone *)zone
{
    MSALSerializedADALCacheProvider *copiedCacheProvider = [[MSALSerializedADALCacheProvider alloc] initWithDelegate:self.delegate error:nil];
    return copiedCacheProvider;
}

#pragma mark - Internal

- (id<MSIDTokenCacheDataSource>)msidTokenCacheDataSource
{
    return self.macTokenCache;
}

#pragma mark - MSIDMacTokenCacheDelegate

- (void)willAccessCache:(__unused MSIDMacTokenCache *)cache
{
    [self.delegate willAccessCache:self];
}

- (void)didAccessCache:(__unused MSIDMacTokenCache *)cache
{
    [self.delegate didAccessCache:self];
}

- (void)willWriteCache:(__unused MSIDMacTokenCache *)cache
{
    [self.delegate willWriteCache:self];
}

- (void)didWriteCache:(__unused MSIDMacTokenCache *)cache
{
    [self.delegate didWriteCache:self];
}

@end
