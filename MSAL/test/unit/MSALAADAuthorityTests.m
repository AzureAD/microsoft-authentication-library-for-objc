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
#import "MSALAADAuthority.h"

@interface MSALAADAuthorityTests : XCTestCase

@end

@implementation MSALAADAuthorityTests

- (void)testInitWithCloudInstanceAudienceAndTenant_whenCloudInstancePublic_audienceCommon_andNilTenant_shouldReturnAuthority
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzurePublicCloudInstance
                                                                     audienceType:MSALAzureADAndPersonalMicrosoftAccountAudience
                                                                        rawTenant:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.microsoftonline.com/common");
}

- (void)testInitWithCloudInstanceAudienceAndTenant_whenCloudInstancePublic_audienceCommon_andNonNilTenant_shouldReturnError
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzurePublicCloudInstance
                                                                     audienceType:MSALAzureADAndPersonalMicrosoftAccountAudience
                                                                        rawTenant:@"contoso.com"
                                                                            error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(authority);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqual(error.code, MSALErrorInternal);
    XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidParameter);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Invalid MSALAudienceType provided. You can only provide rawTenant when using MSALAzureADMyOrgOnlyAudience.");
}

- (void)testInitWithCloudInstanceAudienceAndTenant_whenCloudInstancePublic_audienceMyOrg_andNilTenant_shouldReturnError
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureGermanyCloudInstance
                                                                     audienceType:MSALAzureADMyOrgOnlyAudience
                                                                        rawTenant:nil
                                                                            error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(authority);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqual(error.code, MSALErrorInternal);
    XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidParameter);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Invalid MSALAudienceType provided. You must provide rawTenant when using MSALAzureADMyOrgOnlyAudience.");
}

- (void)testInitWithCloudInstanceAudienceAndTenant_whenCloudInstancePublic_audienceMyOrg_andNonNilTenant_shouldReturnAuthority
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureGermanyCloudInstance
                                                                     audienceType:MSALAzureADMyOrgOnlyAudience
                                                                        rawTenant:@"contoso.de"
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.microsoftonline.de/contoso.de");
}

@end
