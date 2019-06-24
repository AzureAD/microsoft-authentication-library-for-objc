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

#import "MSALLegacySharedAccountTestUtil.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSIDConstants.h"

NSString *const MSALDefaultTestMsaUid = @"00000000-0000-0000-40c0-3bac188d0d10";
NSString *const MSALDefaultTestMsaCid = @"40c03bac188d0d10";

@implementation MSALLegacySharedAccountTestUtil

+ (MSALAccount *)testADALAccount
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.utid"
                                                                       objectId:@"uid"
                                                                       tenantId:@"utid"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    account.accountClaims = @{@"name": @"Contoso User",
                              @"oid": @"uid",
                              @"tid": @"utid"
                              };
    
    return account;
}

+ (MSALAccount *)testMSAAccount
{
    NSString *accountidentifier = [NSString stringWithFormat:@"%@.%@", MSALDefaultTestMsaUid, MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:accountidentifier
                                                                       objectId:MSALDefaultTestMsaUid
                                                                       tenantId:MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    account.accountClaims = @{@"name": @"Contoso User",
                              @"oid": @"uid",
                              @"tid": @"utid"
                              };
    
    return account;
}

+ (NSDictionary *)sampleADALJSONDictionary
{
    return [self sampleADALJSONDictionaryWithAccountId:nil objectId:nil tenantId:nil username:nil];
}

+ (NSDictionary *)sampleADALJSONDictionaryWithAccountId:(NSString *)accountIdentifier
                                               objectId:(NSString *)objectId
                                               tenantId:(NSString *)tenantId
                                               username:(NSString *)username
{
    return @{@"authEndpointUrl": @"https://login.windows.net/common/oauth2/authorize",
             @"id": accountIdentifier ?: [NSUUID UUID].UUIDString,
             @"environment": @"PROD",
             @"oid": objectId ?: [NSUUID UUID].UUIDString,
             @"originAppId": @"com.myapp.app",
             @"tenantDisplayName": @"",
             @"type": @"ADAL",
             @"displayName": @"myDisplayName.contoso.user",
             @"tenantId": tenantId ?: [NSUUID UUID].UUIDString,
             @"username": username ?: @"user@contoso.com"
             };
}

+ (NSDictionary *)sampleMSAJSONDictionary
{
    return [self sampleMSAJSONDictionaryWithAccountId:nil];
}

+ (NSDictionary *)sampleMSAJSONDictionaryWithAccountId:(NSString *)accountIdentifier
{
    return @{@"cid": MSALDefaultTestMsaCid,
             @"email": @"user@outlook.com",
             @"id": accountIdentifier ?: [NSUUID UUID].UUIDString,
             @"originAppId": @"com.myapp.app",
             @"type": @"MSA",
             @"displayName": @"MyDisplayName",
             @"additionalProperties": @{@"myprop1": @"myprop2"},
             @"additionalfield1": @"additionalvalue1"
             };
}

@end
