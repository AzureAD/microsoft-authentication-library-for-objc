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

#import "MSALExternalSerializedCacheProvider.h"
#import "MSIDMacTokenCache.h"
#import "MSALErrorConverter.h"
#import "MSALExternalSerializedCacheProvider+Internal.h"

@interface MSALExternalSerializedCacheProvider()

@property (nonatomic, readwrite) MSALSerializedCacheFormat cacheFormat;
@property (nonatomic, nonnull, readwrite) id<MSALExternalSerializedCacheProviderDelegate> delegate;
@property (nonatomic, readwrite) id<MSIDTokenCacheDataSource> tokenCacheDatasource;

@end

@implementation MSALExternalSerializedCacheProvider

- (instancetype)initWithCacheFormat:(MSALSerializedCacheFormat)cacheFormat
                           delegate:(id<MSALExternalSerializedCacheProviderDelegate>)delegate
                              error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (cacheFormat != MSALLegacyADALCacheFormat)
        {
            if (error)
            {
                NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Unsupported serialized cache format", nil, nil, nil, nil, nil);
                *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
            }
            
            return nil;
        }
        
        _cacheFormat = cacheFormat;
        _delegate = delegate;
        
        // Init datasource
        MSIDMacTokenCache *macTokenCache = [MSIDMacTokenCache new];
       // macTokenCache.delegate = self; // TODO
        self.tokenCacheDatasource = macTokenCache;
    }
    
    return self;
}

- (nullable NSData *)serializeDataWithError:(NSError * _Nullable * _Nullable)error
{
    return nil;
}

- (BOOL)deserialize:(nonnull NSData *)serializedData error:(NSError * _Nullable * _Nullable)error
{
    return NO;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSALExternalSerializedCacheProvider *copiedCacheProvider = [[MSALExternalSerializedCacheProvider alloc] initWithCacheFormat:self.cacheFormat delegate:self.delegate error:nil];
    return copiedCacheProvider;
}

#pragma mark - Internal

- (id<MSIDTokenCacheDataSource>)msidTokenCacheDataSource
{
    return self.tokenCacheDatasource;
}

@end
