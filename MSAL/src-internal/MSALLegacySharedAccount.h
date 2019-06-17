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

@class MSIDJsonObject;
@class MSALAccountEnumerationParameters;
@protocol MSALAccount;

typedef NS_ENUM(NSInteger, MSALLegacySharedAccountVersion)
{
    MSALLegacySharedAccountVersionV1 = 1,
    MSALLegacySharedAccountVersionV2,
    MSALLegacySharedAccountVersionV3
};

typedef NS_ENUM(NSInteger, MSALLegacySharedAccountWriteOperation)
{
    MSALLegacySharedAccountRemoveOperation = 0,
    MSALLegacySharedAccountUpdateOperation
};

NS_ASSUME_NONNULL_BEGIN

@interface MSALLegacySharedAccount : NSObject

@property (nonatomic, readonly) NSDictionary *jsonDictionary;
@property (nonatomic, readonly) NSString *accountType;
@property (nonatomic, readonly) NSString *accountIdentifier;
@property (nonatomic, readonly) NSDictionary *signinStatusDictionary;

- (nullable instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError * _Nullable * _Nullable)error;
- (BOOL)matchesParameters:(MSALAccountEnumerationParameters *)parameters;

- (BOOL)updateAccountWithMSALAccount:(id<MSALAccount>)account
                     applicationName:(NSString *)appName
                           operation:(MSALLegacySharedAccountWriteOperation)operation
                      accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                               error:(NSError * _Nullable * _Nullable)error;


- (nullable instancetype)initWithMSALAccount:(id<MSALAccount>)account
                               accountClaims:(NSDictionary *)claims
                             applicationName:(NSString *)appName
                              accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                                       error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
