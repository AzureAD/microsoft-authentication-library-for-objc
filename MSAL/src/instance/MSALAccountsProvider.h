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
#import "MSIDAccountMetadata.h"
#import "MSALSSOExtensionRequestHandler.h"

@class MSALAccount;
@class MSIDDefaultTokenCacheAccessor;
@class MSALAuthority;
@class MSIDAccount;
@class MSIDIdTokenClaims;
@class MSALExternalAccountHandler;
@class MSALAccountEnumerationParameters;
@class MSIDAccountMetadataCacheAccessor;
@class MSIDRequestParameters;
@class MSIDAccountIdentifier;
@class MSIDRequestParameters;

@interface MSALAccountsProvider : MSALSSOExtensionRequestHandler

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
              accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                          clientId:(NSString *)clientId;

- (instancetype)initWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
              accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                          clientId:(NSString *)clientId
           externalAccountProvider:(MSALExternalAccountHandler *)externalAccountProvider NS_DESIGNATED_INITIALIZER;

- (void)allAccountsFromDevice:(MSALAccountEnumerationParameters *)parameters
            requestParameters:(MSIDRequestParameters *)requestParameters
              completionBlock:(MSALAccountsCompletionBlock)completionBlock;

// Authority filtering (deprecated)
- (void)allAccountsFilteredByAuthority:(MSALAuthority *)authority
                       completionBlock:(MSALAccountsCompletionBlock)completionBlock;

// Convinience
- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error;

- (MSALAccount *)accountForParameters:(MSALAccountEnumerationParameters *)parameters
                                error:(NSError * __autoreleasing *)error;

// Filtering
- (NSArray<MSALAccount *> *)accountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                            error:(NSError * __autoreleasing *)error;

// Check sign in state
- (MSIDAccountMetadataState)signInStateForHomeAccountId:(NSString *)homeAccountId
                                                context:(id<MSIDRequestContext>)context
                                                  error:(NSError **)error;

#pragma mark - Principal account id

- (MSALAccount *)currentPrincipalAccount:(NSError **)error;
- (BOOL)setCurrentPrincipalAccountId:(MSIDAccountIdentifier *)currentAccountId accountEnvironment:(NSString *)accountEnvironment error:(NSError **)error;

@end
