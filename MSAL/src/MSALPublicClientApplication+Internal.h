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

#import "MSALPublicClientApplication.h"

@class MSIDDefaultTokenCacheAccessor;
@class MSIDAccountMetadataCacheAccessor;
@class MSIDAuthority;
@class MSALOauth2Provider;
@class MSALExternalAccountHandler;
@class MSIDRequestParameters;
@class MSIDInteractiveTokenRequestParameters;
@protocol MSIDExtendedTokenCacheDataSource;
@protocol MSIDRequestControlling;
@protocol MSIDTokenRequestProviding;

/// Feature flight for request-scoped nested authentication parameters. Disabled by default; set this flight to enable it.
/// Owner: maagubuzo
extern NSString * _Nonnull const MSAL_FLIGHT_ENABLE_REQUEST_SCOPED_NESTED_AUTH;

@protocol MSALRequestControllerFactoryProviding <NSObject>

- (nullable id<MSIDRequestControlling>)silentControllerForParameters:(nonnull MSIDRequestParameters *)parameters
                                                        forceRefresh:(BOOL)forceRefresh
                                                tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (nullable id<MSIDRequestControlling>)interactiveControllerForParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                                     tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end

@interface MSALPublicClientApplication ()

@property (nonatomic, nonnull) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic, nonnull) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic, nonnull) MSALOauth2Provider *msalOauth2Provider;
@property (nonatomic, nullable) MSALExternalAccountHandler *externalAccountHandler;
@property (nonatomic, nonnull) id<MSALRequestControllerFactoryProviding> requestControllerFactory;

+ (nullable instancetype)applicationWithConfiguration:(nonnull MSALPublicClientApplicationConfig *)config
                                 tokenCacheDataSource:(nullable id<MSIDExtendedTokenCacheDataSource>)tokenCacheDataSource
                                                error:(NSError * _Nullable __autoreleasing * _Nullable)error;

+ (nonnull NSOrderedSet *)defaultOIDCScopes;
- (BOOL)shouldExcludeValidationForAuthority:(nonnull MSIDAuthority *)authority;

@end
