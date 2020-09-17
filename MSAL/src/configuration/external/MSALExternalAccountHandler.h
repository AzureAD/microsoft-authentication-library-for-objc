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

@protocol MSALExternalAccountProviding;
@class MSALResult;
@class MSALAccount;
@protocol MSALExternalAccount;
@class MSALAccountEnumerationParameters;
@class MSALOauth2Provider;

NS_ASSUME_NONNULL_BEGIN

@interface MSALExternalAccountHandler : NSObject

@property (nonatomic, nonnull, readonly) NSArray<id<MSALExternalAccountProviding>> *externalAccountProviders;
@property (nonatomic, nonnull, readonly) MSALOauth2Provider *oauth2Provider;

- (nullable instancetype)initWithExternalAccountProviders:(NSArray<id<MSALExternalAccountProviding>> *)externalAccountProviders
                                           oauth2Provider:(MSALOauth2Provider *)oauth2Provider
                                                    error:(NSError * _Nullable * _Nullable)error;

- (BOOL)updateWithResult:(MSALResult *)result error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeAccount:(MSALAccount *)account wipeAccount:(BOOL)wipeAccount error:(NSError * _Nullable * _Nullable)error;
- (nullable NSArray<MSALAccount *> *)allExternalAccountsWithParameters:(MSALAccountEnumerationParameters *)parameters error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
