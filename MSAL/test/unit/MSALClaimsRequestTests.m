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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSALClaimsRequest.h"
#import "MSALIndividualClaimRequest.h"
#import "MSALIndividualClaimRequestAdditionalInfo.h"

@interface MSALClaimsRequestTests : XCTestCase

@end

@implementation MSALClaimsRequestTests

- (void)setUp
{
}

- (void)tearDown
{
}

#pragma mark - Init with valid json string

- (void)testInitWithJSONString_whenClaimRequestedInDefaultMannerInIdTokenTarget_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"nickname\": null }}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"nickname", claim.name);
    XCTAssertNil(claim.additionalInfo);
}

- (void)testInitWithJSONString_whenClaimRequestedInDefaultMannerInIdAccessTokenTarget_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"access_token\": {\"nickname\": null }}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetAccessToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"nickname", claim.name);
    XCTAssertNil(claim.additionalInfo);
}

- (void)testInitWithJSONString_whenClaimRequestedInTwoTargets_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"nickname\": null }, \"access_token\": {\"some_claim\": null }}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"nickname", claim.name);
    XCTAssertNil(claim.additionalInfo);
    claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetAccessToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    claim = claims.firstObject;
    XCTAssertEqualObjects(@"some_claim", claim.name);
    XCTAssertNil(claim.additionalInfo);
}

- (void)testInitWithJSONString_whenClaimRequestedWithEssentialFlag_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"given_name\": {\"essential\": true}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"given_name", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertTrue(claim.additionalInfo.essential);
    XCTAssertNil(claim.additionalInfo.value);
    XCTAssertNil(claim.additionalInfo.values);
}

- (void)testInitWithJSONString_whenClaimRequestedWithValue_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"sub\": {\"value\": 248289761001}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"sub", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertNil(claim.additionalInfo.essential);
    XCTAssertEqualObjects(@248289761001, claim.additionalInfo.value);
    XCTAssertNil(claim.additionalInfo.values);
}

- (void)testInitWithJSONString_whenClaimRequestedWithValueAndRequestedTwice_shouldInitClaimRequestAndContainOnlyOneRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"sub\": {\"value\": 1}, \"sub\": {\"value\": 2}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"sub", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertNil(claim.additionalInfo.essential);
    XCTAssertEqualObjects(@2, claim.additionalInfo.value);
    XCTAssertNil(claim.additionalInfo.values);
}

- (void)testInitWithJSONString_whenClaimRequestedWithValues_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"acr\": {\"values\": [\"urn:mace:incommon:iap:silver\", \"urn:mace:incommon:iap:bronze\"]}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"acr", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertNil(claim.additionalInfo.essential);
    XCTAssertNil(claim.additionalInfo.value);
    __auto_type expectedValues = [[NSSet alloc] initWithArray:@[@"urn:mace:incommon:iap:bronze", @"urn:mace:incommon:iap:silver"]];
    XCTAssertEqualObjects(expectedValues, claim.additionalInfo.values);
}

- (void)testInitWithJSONString_whenClaimRequestedWithAllPossibleValues_shouldInitClaimRequest
{
    NSString *claimsJsonString = @"{\"id_token\": {\"acr\": {\"essential\": true, \"value\": 248289761001, \"values\": [\"urn:mace:incommon:iap:silver\", \"urn:mace:incommon:iap:bronze\"]}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSALIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"acr", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertTrue(claim.additionalInfo.essential);
    XCTAssertEqualObjects(@248289761001, claim.additionalInfo.value);
    __auto_type expectedValues = [[NSSet alloc] initWithArray:@[@"urn:mace:incommon:iap:bronze", @"urn:mace:incommon:iap:silver"]];
    XCTAssertEqualObjects(expectedValues, claim.additionalInfo.values);
}

#pragma mark - Init with invalid json string

- (void)testInitWithJSONString_whenJsonStringIsCorrupted_shouldFailWithError
{
    NSString *claimsJsonString = @"{\"id_token\": \"nickname\": null }}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    XCTAssertNil(claimsRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 3840);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
}

- (void)testInitWithJSONString_whenClaimRequestedInInvalidTarget_shouldFailWithError
{
    NSString *claimsJsonString = @"{\"qwe\": {\"nickname\": null }}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    XCTAssertNil(claimsRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Invalid claims target: qwe");
}

- (void)testInitWithJSONString_whenClaimRequestedWithInvalidAdditionalInfo_shouldFailWithError
{
    NSString *claimsJsonString = @"{\"id_token\": {\"sub\": {\"invalid_param\": 1}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    XCTAssertNil(claimsRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Failed to init claim additional info from json string.");
}

- (void)testInitWithJSONString_whenClaimRequestedWithInvalidEssential_shouldFailWithError
{
    NSString *claimsJsonString = @"{\"id_token\": {\"given_name\": {\"essential\": \"qwe\"}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    XCTAssertNil(claimsRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"essential is not a NSNumber.");
}

- (void)testInitWithJSONString_whenClaimRequestedWithInvalidValues_shouldFailWithError
{
    NSString *claimsJsonString = @"{\"id_token\": {\"acr\": {\"essential\": true, \"value\": 248289761001, \"values\": \"urn:mace:incommon:iap:silver\"}}}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    XCTAssertNil(claimsRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"values is not an NSArray.");
}

- (void)testInitWithJSONString_whenClaimRequestedWithoutNestedClaimsDictionary_shouldFailWithError
{
    NSString *claimsJsonString = @"{\"id_token\": \"acr\"}";
    NSError *error;
    
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    XCTAssertNil(claimsRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"id_token is not a NSDictionary.");
}

#pragma mark - testJSONString

- (void)testJSONString_whenClaimsRequestWithoutClaims_shouldReturnValidJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    XCTAssertEqualObjects(@"{}", jsonString);
}

- (void)testJSONString_whenClaimRequestedInDefaultManner_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"nickname"];
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    XCTAssertEqualObjects(@"{\"id_token\":{\"nickname\":null}}", jsonString);
}

- (void)testJSONString_whenClaimRequestedWithEssentialFlag_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"given_name"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @YES;
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    XCTAssertEqualObjects(@"{\"id_token\":{\"given_name\":{\"essential\":true}}}", jsonString);
}

- (void)testJSONString_whenClaimRequestedWithValue_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @248289761001;
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    XCTAssertEqualObjects(@"{\"id_token\":{\"sub\":{\"value\":248289761001}}}", jsonString);
}

- (void)testJSONString_whenClaimRequestedWithValues_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"acr"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.values = [[NSSet alloc] initWithObjects:@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze", nil];
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    XCTAssertEqualObjects(@"{\"id_token\":{\"acr\":{\"values\":[\"urn:mace:incommon:iap:bronze\",\"urn:mace:incommon:iap:silver\"]}}}", jsonString);
}

- (void)testJSONString_whenClaimRequestedWithAllPossibleValues_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"acr"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @YES;
    claimRequest.additionalInfo.value = @248289761001;
    claimRequest.additionalInfo.values = [[NSSet alloc] initWithObjects:@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze", nil];
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    __auto_type expectedJsonString = @"{\"id_token\":{\"acr\":{\"value\":248289761001,\"values\":[\"urn:mace:incommon:iap:bronze\",\"urn:mace:incommon:iap:silver\"],\"essential\":true}}}";
    XCTAssertEqualObjects(expectedJsonString, jsonString);
}

- (void)testJSONString_whenClaimRequestedWithValueAndRequestedTwice_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @2;
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *jsonString = [claimsRequest jsonString];
    
    __auto_type expectedJsonString = @"{\"id_token\":{\"sub\":{\"value\":2}}}";
    XCTAssertEqualObjects(expectedJsonString, jsonString);
}

#pragma mark - requestClaim

- (void)testRequestClaim_whenSameClaimRequestedTwice_shouldReplaceCurrentRequest
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @2;
    
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    __auto_type requests = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertEqual(1, requests.count);
    MSALIndividualClaimRequest *request = requests.firstObject;
    XCTAssertEqualObjects(@"sub", request.name);
    XCTAssertNotNil(request.additionalInfo);
    XCTAssertEqualObjects(@2, request.additionalInfo.value);
}

#pragma mark - testJSONString from invalid parameters

- (void)testJSONString_whenClaimsRequestWithInvalidValue_shouldFailWithException
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = [NSDate new];
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    XCTAssertThrows([claimsRequest jsonString]);
}

- (void)testJSONString_whenClaimsRequestWithInvalidValues_shouldFailWithException
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSALIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.values = [[NSSet alloc] initWithObjects:[NSDate new], nil];
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    XCTAssertThrows([claimsRequest jsonString]);
}

- (void)testJSONString_whenClaimsRequestWithNilName_shouldReturnNil
{
    __auto_type claimsRequest = [MSALClaimsRequest new];
    __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithName:@"sub"];
    NSString *name;
    claimRequest.name = name;
    [claimsRequest requestClaim:claimRequest forTarget:MSALClaimsRequestTargetIdToken];
    
    NSString *result = [claimsRequest jsonString];
    
    XCTAssertNil(result);
}

#pragma mark - removeClaimRequestWithName

- (void)testRemoveClaimRequestWithName_whenClaimExistsInTarget_shouldRemoveIt
{
    NSString *claimsJsonString = @"{\"id_token\": {\"claim1\": null, \"claim2\": null, \"claim3\": null }}";
    NSError *error;
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];

    [claimsRequest removeClaimRequestWithName:@"claim2" target:MSALClaimsRequestTargetIdToken];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 2);
    MSALIndividualClaimRequest *claim = claims[0];
    XCTAssertEqualObjects(@"claim1", claim.name);
    claim = claims[1];
    XCTAssertEqualObjects(@"claim3", claim.name);
}

- (void)testRemoveClaimRequestWithName_whenClaimDoesntExistInTarget_shouldIgnoreIt
{
    NSString *claimsJsonString = @"{\"id_token\": {\"claim1\": null, \"claim3\": null }}";
    NSError *error;
    __auto_type claimsRequest = [[MSALClaimsRequest alloc] initWithJSONString:claimsJsonString error:&error];
    
    [claimsRequest removeClaimRequestWithName:@"claim2" target:MSALClaimsRequestTargetIdToken];
    
    __auto_type claims = [claimsRequest claimRequestsForTarget:MSALClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 2);
    MSALIndividualClaimRequest *claim = claims[0];
    XCTAssertEqualObjects(@"claim1", claim.name);
    claim = claims[1];
    XCTAssertEqualObjects(@"claim3", claim.name);
}

@end
