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

@protocol MSALAccount;
@class MSALTenantProfile;
@class MSALAccountEnumerationParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 Use this protocol if you have external account storage in addition to MSAL account storage.
 For example, if you find yourself in situation where on each MSAL completion block invocation you are updating accounts in your own storage,
 it might be beneficial to instead use MSALExternalAccountProviding extensibility feature.
 */

@protocol MSALExternalAccountProviding <NSObject>

/**
 This is called when new and/or updated account is available.
 */
- (BOOL)updateAccount:(id<MSALAccount>)account
        idTokenClaims:(NSDictionary *)idTokenClaims
                error:(NSError * _Nullable * _Nullable)error;

/**
 This is triggered when removal of an account is necessary.
 It normally happens when the app calls removeAccount API in MSAL.
 But it can also happen in other circumstances when MSAL needs to cleanup account.
 */
- (BOOL)removeAccount:(id<MSALAccount>)account
       tenantProfiles:(nullable NSArray<MSALTenantProfile *> *)tenantProfiles
                error:(NSError * _Nullable * _Nullable)error;

/**
 This is triggered when MSAL needs to enumerate account.
 Return your accounts that match parameters.
 MSAL will merge external accounts with its own internal storage and return a combined list of accounts that mathes specified parameters.
 */
- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
