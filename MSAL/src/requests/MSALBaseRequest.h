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
#import "MSALTelemetryApiId.h"
#import "MSALAuthority.h"

@class MSALTokenCache;
@class MSALTokenResponse;
@class MSALTokenCacheItem;
@class MSALTelemetryAPIEvent;

@interface MSALBaseRequest : NSObject
{
    @protected
    MSALRequestParameters *_parameters;
    MSALAuthority *_authority;
    MSALTelemetryApiId _apiId;
}

@property (nullable) MSALTokenResponse *response;
@property (nullable) MSALTokenCacheItem *accessTokenItem;
@property (nonnull, readonly) MSALRequestParameters *parameters;

/* Returns the complete set of scopes to be sent out with a token request */
- (nonnull MSALScopes *)requestScopes:(nullable MSALScopes *)extraScopes;

- (nullable id)initWithParameters:(nonnull MSALRequestParameters *)parameters
                            error:(NSError * __nullable __autoreleasing * __nullable)error;

- (BOOL)validateScopeInput:(nullable MSALScopes *)scopes
                     error:(NSError * __nullable __autoreleasing * __nullable)error;

- (void)run:(nonnull MSALCompletionBlock)completionBlock;
- (void)acquireToken:(nonnull MSALCompletionBlock)completionBlock;

- (void)addAdditionalRequestParameters:(nonnull NSMutableDictionary<NSString *, NSString *> *)parameters;

- (void)resolveEndpoints:(nonnull MSALAuthorityCompletion)completionBlock;

- (nonnull MSALTelemetryAPIEvent *)getTelemetryAPIEvent;

- (void)stopTelemetryEvent:(nonnull MSALTelemetryAPIEvent *)event error:(nullable NSError *)error;

@end
