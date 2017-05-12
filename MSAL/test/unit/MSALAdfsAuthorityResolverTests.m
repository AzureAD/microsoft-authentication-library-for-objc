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

#import "MSALTestCase.h"
#import "MSALAdfsAuthorityResolver.h"
#import "MSALTestSwizzle.h"

#import "MSALDrsDiscoveryRequest.h"
#import "MSALDrsDiscoveryResponse.h"
#import "MSALWebFingerRequest.h"
#import "MSALWebFingerResponse.h"

#define TRUSTED_REALM @"http://schemas.microsoft.com/rel/trusted-realm"

typedef void (^MSALDrsCompletionBlock)(MSALDrsDiscoveryResponse *response, NSError *error);
typedef void (^MSALWebFingerCompletionBlock)(MSALWebFingerResponse *response, NSError *error);

@interface MSALAdfsAuthorityResolverTests : MSALTestCase

@end

@implementation MSALAdfsAuthorityResolverTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultOpenIdConfigurationEndpointForAuthority_whenAuthority_shouldReturnURLString
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSString *expectedEndpoint = @"https://fs.fabrikam.com/adfs/.well-known/openid-configuration";
    
    NSString *endpoint = [resolver defaultOpenIdConfigurationEndpointForAuthority:[NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"]];
    
    XCTAssertEqualObjects(endpoint, expectedEndpoint);
}

- (void)testDefaultOpenIdConfigurationEndpointForAuthority_whenNilAuthority_shouldReturnNil
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    XCTAssertNil([resolver defaultOpenIdConfigurationEndpointForAuthority:nil]);
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenNoValidate_shouldReturnEndpoint
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    NSString *expectedEndpoint = @"https://fs.fabrikam.com/adfs/.well-known/openid-configuration";
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:NO
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
    {
        
        XCTAssertNil(error);
        XCTAssertNotNil(endpoint);
        
        XCTAssertEqualObjects(endpoint, expectedEndpoint);
    }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenBadUpn_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable";

    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorInvalidParameter);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"UPN"]);
     }];
}


- (void)testOpenIDConfigurationEndpointForAuthority_whenNilDrsResponse_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                              class:[MSALDrsDiscoveryRequest class]
                              block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         completionBlock(nil, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"DRS discovery"]);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsResponseMissingPassiveAuthEndpoint_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{ @"IdentityProviderService" : @{ } } error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"DRS discovery"]);
     }];

}


- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsResponseMissingIdentityProviderService_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{} error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"DRS discovery"]);
     }];
    
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerResponseMissing_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{ @"IdentityProviderService" : @{ @"PassiveAuthEndpoint" : @"https://someendpoint.com"} } error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [MSALTestSwizzle classMethod:@selector(requestForAuthenticationEndpoint:authority:context:completionBlock:)
                           class:[MSALWebFingerRequest class]
                           block:(id)^(id obj, NSString *authenticationEndpoint, NSURL *authority, id<MSALRequestContext>context, MSALWebFingerCompletionBlock completionBlock)
     {
         (void)obj;
         (void)authenticationEndpoint;
         (void)authority;
         (void)context;
         
         completionBlock(nil, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerResponseEmptyLinks_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{ @"IdentityProviderService" : @{ @"PassiveAuthEndpoint" : @"https://someendpoint.com"} } error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [MSALTestSwizzle classMethod:@selector(requestForAuthenticationEndpoint:authority:context:completionBlock:)
                           class:[MSALWebFingerRequest class]
                           block:(id)^(id obj, NSString *authenticationEndpoint, NSURL *authority, id<MSALRequestContext>context, MSALWebFingerCompletionBlock completionBlock)
     {
         (void)obj;
         (void)authenticationEndpoint;
         (void)authority;
         (void)context;
         
         MSALWebFingerResponse *response =
         [[MSALWebFingerResponse alloc] initWithJson:@{ @"links" : @[] }
                                               error:nil];
         completionBlock(response, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerResponseRealmNotTrusted_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    NSString *rel = @"https://schemas.somehost.com/rel/not-trusted";
    NSString *href = @"https://someref.com";
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{ @"IdentityProviderService" : @{ @"PassiveAuthEndpoint" : @"https://someendpoint.com"} } error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [MSALTestSwizzle classMethod:@selector(requestForAuthenticationEndpoint:authority:context:completionBlock:)
                           class:[MSALWebFingerRequest class]
                           block:(id)^(id obj, NSString *authenticationEndpoint, NSURL *authority, id<MSALRequestContext>context, MSALWebFingerCompletionBlock completionBlock)
     {
         (void)obj;
         (void)authenticationEndpoint;
         (void)authority;
         (void)context;
         
         MSALWebFingerResponse *response =
         [[MSALWebFingerResponse alloc] initWithJson:@{ @"links" : @[ @{@"href" : href, @"rel" : rel} ]}
                                               error:nil];
         
         
         completionBlock(response, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
     }];
}


- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerLinkHrefNotMatchAuthority_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    NSString *rel = TRUSTED_REALM;
    NSString *href = @"https://someref_not_match_authority.com";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{ @"IdentityProviderService" : @{ @"PassiveAuthEndpoint" : @"https://someendpoint.com"} } error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [MSALTestSwizzle classMethod:@selector(requestForAuthenticationEndpoint:authority:context:completionBlock:)
                           class:[MSALWebFingerRequest class]
                           block:(id)^(id obj, NSString *authenticationEndpoint, NSURL *authority, id<MSALRequestContext>context, MSALWebFingerCompletionBlock completionBlock)
     {
         (void)obj;
         (void)authenticationEndpoint;
         (void)authority;
         (void)context;
         
         MSALWebFingerResponse *response =
         [[MSALWebFingerResponse alloc] initWithJson:@{ @"links" : @[ @{@"href" : href, @"rel" : rel} ]}
                                               error:nil];
         completionBlock(response, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenNormalFlow_shouldReturnEndpointWithNoError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    NSString *upn = @"displayable@contoso.com";
    
    NSString *rel = TRUSTED_REALM;
    NSString *href = authority.absoluteString;
    
    NSString *expectedEndpoint = @"https://fs.fabrikam.com/adfs/.well-known/openid-configuration";
    
    [MSALTestSwizzle classMethod:@selector(queryEnrollmentServerEndpointForDomain:adfsType:context:completionBlock:)
                           class:[MSALDrsDiscoveryRequest class]
                           block:(id)^(id obj, NSString *domain, AdfsType type, id<MSALRequestContext> context, MSALDrsCompletionBlock completionBlock)
     {
         (void)domain;
         (void)obj;
         (void)type;
         (void)context;
         
         MSALDrsDiscoveryResponse *response =
         [[MSALDrsDiscoveryResponse alloc] initWithJson:@{ @"IdentityProviderService" : @{ @"PassiveAuthEndpoint" : @"https://someendpoint.com"} } error:nil];
         
         completionBlock(response, nil);
     }];
    
    
    [MSALTestSwizzle classMethod:@selector(requestForAuthenticationEndpoint:authority:context:completionBlock:)
                           class:[MSALWebFingerRequest class]
                           block:(id)^(id obj, NSString *authenticationEndpoint, NSURL *authority, id<MSALRequestContext>context, MSALWebFingerCompletionBlock completionBlock)
     {
         (void)obj;
         (void)authenticationEndpoint;
         (void)authority;
         (void)context;
         
         MSALWebFingerResponse *response =
         [[MSALWebFingerResponse alloc] initWithJson:@{ @"links" : @[ @{@"href" : href, @"rel" : rel} ]}
                                               error:nil];
         completionBlock(response, nil);
     }];
    
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(endpoint);
         
         XCTAssertEqualObjects(endpoint, expectedEndpoint);
     }];
}

@end
