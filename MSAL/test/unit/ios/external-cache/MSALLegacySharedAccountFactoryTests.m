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

#import <XCTest/XCTest.h>
#import "MSALLegacySharedAccountFactory.h"
#import "MSALLegacySharedADALAccount.h"
#import "MSALLegacySharedMSAAccount.h"

@interface MSALLegacySharedAccountFactoryTests : XCTestCase

@end

@implementation MSALLegacySharedAccountFactoryTests

#pragma mark - accountWithJSONDictionary

- (void)testAccountWithJSONDictionary_whenTypeMissing_shouldReturnNilFillError
{
    NSDictionary *jsonDictionary = [self sampleJSONDictionaryWithAccountType:nil];
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [MSALLegacySharedAccountFactory accountWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
}

- (void)testAccountWithJSONDictionary_whenTypeUnknown_shouldReturnNilAndFillError
{
    NSDictionary *jsonDictionary = [self sampleJSONDictionaryWithAccountType:@"UnknownType"];
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [MSALLegacySharedAccountFactory accountWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
}

- (void)testAccountWithJSONDictionary_whenTypeADAL_shouldReturnADALAccount
{
    NSDictionary *jsonDictionary = [self sampleJSONDictionaryWithAccountType:@"ADAL"];
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [MSALLegacySharedAccountFactory accountWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertTrue([account isKindOfClass:[MSALLegacySharedADALAccount class]]);
}

- (void)testAccountWithJSONDictionary_whenTypeMSA_shouldReturnMSAAccount
{
    NSDictionary *jsonDictionary = [self sampleJSONDictionaryWithAccountType:@"MSA"];
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [MSALLegacySharedAccountFactory accountWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertTrue([account isKindOfClass:[MSALLegacySharedMSAAccount class]]);
}

#pragma mark - Helpers

- (NSDictionary *)sampleJSONDictionaryWithAccountType:(NSString *)accountType
{
    return @{@"authEndpointUrl": @"https://contoso.com/common",
             @"id": [NSUUID UUID].UUIDString,
             @"environment": @"PROD",
             @"oid": [NSUUID UUID].UUIDString,
             @"cid": @"40c03bac188d0d10",
             @"originAppId": @"com.myapp.app",
             @"tenantDisplayName": @"",
             @"type": accountType ?: [NSNull null],
             @"tenantId": [NSUUID UUID].UUIDString,
             @"username": @"user@contoso.com"
             };
}

@end
