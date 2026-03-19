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

#pragma mark - France Sovereign Cloud

- (void)testInitWithCloudInstance_France_MyOrg_NilTenant_shouldReturnError
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureFranceCloudInstance
                                                                     audienceType:MSALAzureADMyOrgOnlyAudience
                                                                        rawTenant:nil
                                                                            error:&error];

    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqual(error.code, MSALErrorInternal);
    XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidParameter);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Invalid MSALAudienceType provided. You must provide rawTenant when using MSALAzureADMyOrgOnlyAudience.");
}

- (void)testInitWithCloudInstance_France_MyOrg_NonNilTenant_shouldReturnAuthority
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureFranceCloudInstance
                                                                     audienceType:MSALAzureADMyOrgOnlyAudience
                                                                        rawTenant:@"contoso.fr"
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.sovcloud-identity.fr/contoso.fr");
}

- (void)testInitWithCloudInstance_France_Common_NilTenant_shouldReturnAuthority
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureFranceCloudInstance
                                                                     audienceType:MSALAzureADAndPersonalMicrosoftAccountAudience
                                                                        rawTenant:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.sovcloud-identity.fr/common");
}

- (void)testInitWithCloudInstance_France_Common_NonNilTenant_shouldReturnError
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureFranceCloudInstance
                                                                     audienceType:MSALAzureADAndPersonalMicrosoftAccountAudience
                                                                        rawTenant:@"contoso.fr"
                                                                            error:&error];

    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqual(error.code, MSALErrorInternal);
    XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidParameter);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Invalid MSALAudienceType provided. You can only provide rawTenant when using MSALAzureADMyOrgOnlyAudience.");
}

- (void)testInitWithCloudInstance_France_MultipleOrgs_shouldReturnAuthority
{
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureFranceCloudInstance
                                                                     audienceType:MSALAzureADMultipleOrgsAudience
                                                                        rawTenant:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.sovcloud-identity.fr/organizations");
}

- (void)testInitWithURL_France_shouldReturnAuthority
{
    NSError *error = nil;
    NSURL *franceURL = [NSURL URLWithString:@"https://login.sovcloud-identity.fr/common"];
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithURL:franceURL
                                                                  error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.sovcloud-identity.fr/common");
}

#pragma mark - Regression: all MSALAzureCloudInstance values produce a non-nil environment

- (void)testEnvironmentFromCloudInstance_allKnownCasesReturnNonNilEnvironment
{
    // This test is a guard against future enum additions that forget to add
    // a corresponding case in environmentFromCloudInstance:.
    // If a new MSALAzureCloudInstance value is added, add it here AND in the switch.
    NSArray<NSNumber *> *allInstances = @[
        @(MSALAzurePublicCloudInstance),
        @(MSALAzureChinaCloudInstance),
        @(MSALAzureGermanyCloudInstance),
        @(MSALAzureUsGovernmentCloudInstance),
        @(MSALAzureFranceCloudInstance),
    ];

    for (NSNumber *instanceNumber in allInstances)
    {
        MSALAzureCloudInstance instance = (MSALAzureCloudInstance)instanceNumber.integerValue;
        NSError *error = nil;
        // Use organizations audience (valid for all instances without requiring rawTenant)
        MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:instance
                                                                         audienceType:MSALAzureADMultipleOrgsAudience
                                                                            rawTenant:nil
                                                                                error:&error];
        XCTAssertNil(error, @"Unexpected error for cloud instance %ld: %@", (long)instance, error);
        XCTAssertNotNil(authority, @"nil authority returned for cloud instance %ld", (long)instance);
        XCTAssertNotNil(authority.url, @"nil URL for cloud instance %ld", (long)instance);
    }
}

- (void)testInitWithCloudInstance_Germany_unchangedAfterFranceAddition
{
    // Regression: adding France must not alter Germany behaviour.
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithCloudInstance:MSALAzureGermanyCloudInstance
                                                                     audienceType:MSALAzureADMultipleOrgsAudience
                                                                        rawTenant:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(authority);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://login.microsoftonline.de/organizations");
}

@end
