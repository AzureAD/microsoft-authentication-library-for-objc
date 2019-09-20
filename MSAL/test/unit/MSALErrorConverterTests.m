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
#import "MSALErrorConverter+Internal.h"
#include "MSIDError.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSALResult.h"
#import "MSALAADOauth2Provider.h"

@interface MSALErrorConverterTests : XCTestCase

@end

@implementation MSALErrorConverterTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testErrorFromMsidError_whenPassInNilError_shouldReturnNil
{
    XCTAssertNil([MSALErrorConverter msalErrorFromMsidError:nil]);
}


- (void)testErrorConversion_whenPassInNilDomain_ShouldReturnNil {
    NSString *msalDomain = nil;
    
    NSError *msalError = [MSALErrorConverter errorWithDomain:msalDomain
                                                        code:0
                                            errorDescription:nil
                                                  oauthError:nil
                                                    subError:nil
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    XCTAssertNil(msalError);
}

- (void)testErrorConversion_whenOnlyErrorDomainIsMapped_ErrorCodeShouldBeKept {
    NSInteger errorCode = -9999;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    NSError *underlyingError = [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecItemNotFound userInfo:nil];
    NSUUID *correlationId = [NSUUID UUID];
    NSDictionary *httpHeaders = @{@"fake header key" : @"fake header value"};
    NSString *httpResponseCode = @"-99999";
    
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSIDKeychainErrorDomain
                                                        code:errorCode
                                            errorDescription:errorDescription
                                                  oauthError:oauthError
                                                    subError:subError
                                             underlyingError:underlyingError
                                               correlationId:correlationId
                                                    userInfo:@{MSIDHTTPHeadersKey : httpHeaders,
                                                               MSIDHTTPResponseCodeKey : httpResponseCode,
                                                               @"additional_user_info": @"unmapped_userinfo"}
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    
    NSString *expectedErrorDomain = NSOSStatusErrorDomain;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, errorCode);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertNil(msalError.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthSubErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[NSUnderlyingErrorKey], underlyingError);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPHeadersKey], httpHeaders);
    XCTAssertNil(msalError.userInfo[MSIDHTTPHeadersKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPResponseCodeKey], httpResponseCode);
    XCTAssertNil(msalError.userInfo[MSIDHTTPResponseCodeKey]);
    XCTAssertEqualObjects(msalError.userInfo[@"additional_user_info"], @"unmapped_userinfo");
}

- (void)testErrorConversion_whenUnclassifiedInternalMSALErrorPassed_shouldMapToInternal
{
    NSInteger errorCode = -42400;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSALErrorDomain
                                                        code:errorCode
                                            errorDescription:errorDescription
                                                  oauthError:oauthError
                                                    subError:subError
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    
    NSString *expectedErrorDomain = MSALErrorDomain;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, MSALErrorInternal);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertEqualObjects(msalError.userInfo[MSALInternalErrorCodeKey], @(-42400));
}

- (void)testErrorConversion_whenUnclassifiedRecoverableErrorPassed_shouldMapToRecoverable
{
    NSInteger errorCode = MSALErrorUserCanceled;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSALErrorDomain
                                                        code:errorCode
                                            errorDescription:errorDescription
                                                  oauthError:oauthError
                                                    subError:subError
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    
    NSString *expectedErrorDomain = MSALErrorDomain;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, MSALErrorUserCanceled);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertNil(msalError.userInfo[MSALInternalErrorCodeKey]);
}

- (void)testErrorConversion_whenUnclassifiedUnrecoverableErrorPassed_andClassifyErrorsNO_shouldNotClassify
{
    NSInteger errorCode = -42400;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSALErrorDomain
                                                        code:errorCode
                                            errorDescription:errorDescription
                                                  oauthError:oauthError
                                                    subError:subError
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:NO
                                          msalOauth2Provider:nil];
    
    NSString *expectedErrorDomain = MSALErrorDomain;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, -42400);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertNil(msalError.userInfo[MSALInternalErrorCodeKey]);
}

- (void)testErrorConversion_whenBothErrorDomainAndCodeAreMapped_shouldMapBoth {
    NSInteger errorCode = MSIDErrorInteractionRequired;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    NSError *underlyingError = [NSError errorWithDomain:MSIDErrorDomain code:MSIDErrorServerInvalidGrant userInfo:@{MSIDOAuthSubErrorKey : @"basic_action"}];
    NSUUID *correlationId = [NSUUID UUID];
    NSDictionary *httpHeaders = @{@"fake header key" : @"fake header value"};
    NSString *httpResponseCode = @"-99999";
    
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSIDOAuthErrorDomain
                                                        code:errorCode
                                            errorDescription:errorDescription
                                                  oauthError:oauthError
                                                    subError:subError
                                             underlyingError:underlyingError
                                               correlationId:correlationId
                                                    userInfo:@{MSIDHTTPHeadersKey : httpHeaders,
                                                               MSIDHTTPResponseCodeKey : httpResponseCode,
                                                               @"additional_user_info": @"unmapped_userinfo",
                                                               MSIDInvalidTokenResultKey : [self testTokenResult]}
                                              classifyErrors:YES
                                          msalOauth2Provider:[[MSALAADOauth2Provider alloc] initWithClientId:@"someClientId"
                                                                                                  tokenCache:nil
                                                                                        accountMetadataCache:nil]];
    
    NSString *expectedErrorDomain = MSALErrorDomain;
    NSInteger expectedErrorCode = MSALErrorInteractionRequired;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, expectedErrorCode);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertNil(msalError.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthSubErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPHeadersKey], httpHeaders);
    XCTAssertNil(msalError.userInfo[MSIDHTTPHeadersKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPResponseCodeKey], httpResponseCode);
    XCTAssertNil(msalError.userInfo[MSIDHTTPResponseCodeKey]);
    XCTAssertEqualObjects(msalError.userInfo[@"additional_user_info"], @"unmapped_userinfo");
    XCTAssertNil(msalError.userInfo[MSIDInvalidTokenResultKey]);
    XCTAssertNotNil(msalError.userInfo[MSALInvalidResultKey]);
    MSALResult *result = msalError.userInfo[MSALInvalidResultKey];
    XCTAssertEqualObjects(result.accessToken, @"access-token");
    
    NSError *mappedUnderlyingError = msalError.userInfo[NSUnderlyingErrorKey];
    XCTAssertEqualObjects(mappedUnderlyingError.domain, MSALErrorDomain);
    XCTAssertEqual(mappedUnderlyingError.code, MSALErrorInternal);
    XCTAssertEqual(mappedUnderlyingError.userInfo[MSALOAuthSubErrorKey], @"basic_action");
    XCTAssertEqual([mappedUnderlyingError.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidGrant);
}

- (MSIDTokenResult *)testTokenResult
{
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:@"access-token"
                                                               responseRT:@"refresh-token"
                                                               responseID:nil
                                                            responseScope:nil
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];

    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    MSIDConfiguration *conf = [[MSIDConfiguration alloc] initWithAuthority:authority redirectUri:nil clientId:@"myclient" target:@"test.scope"];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:conf];
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:conf];
    MSIDAccount *account = [factory accountFromResponse:response configuration:conf];

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:refreshToken
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:[NSUUID UUID]
                                                             tokenResponse:response];

    return result;
}

/*!
 It's very easy to add an additional error in MSID space, but forget to map it to appropriate AD error.
 This test is just making sure that each error under MSIDErrorDomain is mapped to a different AD error
 and will fail if new error is added and left unmapped.
 
 This test doesn't test that the error has been mapped correctly.
 */

- (void)testErrorConversion_whenErrorConverterInitialized_shouldMapAllMSIDErrors
{
    NSDictionary *domainsAndCodes = MSIDErrorDomainsAndCodes();
    
    for (NSString *domain in domainsAndCodes)
    {
        NSArray *codes = domainsAndCodes[domain];
        for (NSNumber *code in codes)
        {
            MSIDErrorCode errorCode = [code integerValue];
            
            NSError *error = [MSALErrorConverter errorWithDomain:domain
                                                            code:[code integerValue]
                                                errorDescription:nil
                                                      oauthError:nil
                                                        subError:nil
                                                 underlyingError:nil
                                                   correlationId:nil
                                                        userInfo:nil
                                                  classifyErrors:YES
                                              msalOauth2Provider:nil];
            
            XCTAssertNotEqual(error.code, errorCode);
            XCTAssertNotEqualObjects(error.domain, domain);
            
        }
    }
}

- (void)testErrorConversion_whenDomainIsMappedAndCodeMissing_shouldReturnMSALInternalError
{
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSIDErrorDomain
                                                        code:123456
                                            errorDescription:@"Unmapped code error"
                                                  oauthError:nil
                                                    subError:nil
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    
    XCTAssertEqualObjects(msalError.domain, MSALErrorDomain);
    XCTAssertEqual(msalError.code, MSALErrorInternal);
    
}

- (void)testErrorConversion_whenDomainNotMapped_shouldNotTouchCode
{
    NSError *msalError = [MSALErrorConverter errorWithDomain:@"Unmapped Domain"
                                                        code:MSIDErrorUserCancel
                                            errorDescription:nil
                                                  oauthError:nil
                                                    subError:nil
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    
    XCTAssertEqualObjects(msalError.domain, @"Unmapped Domain");
    XCTAssertEqual(msalError.code, MSIDErrorUserCancel);
}

- (void)testErrorConversion_whenErrorMappedToInternalError_shouldSetInternalErrorToUnexpected
{
    NSError *msalError = [MSALErrorConverter errorWithDomain:MSIDErrorDomain
                                                        code:MSIDErrorInternal
                                            errorDescription:nil
                                                  oauthError:nil
                                                    subError:nil
                                             underlyingError:nil
                                               correlationId:nil
                                                    userInfo:nil
                                              classifyErrors:YES
                                          msalOauth2Provider:nil];
    
    XCTAssertEqualObjects(msalError.domain, MSALErrorDomain);
    XCTAssertEqual(msalError.code, MSALErrorInternal);
    NSNumber *internalCode = msalError.userInfo[MSALInternalErrorCodeKey];
    XCTAssertEqual([internalCode integerValue], MSALInternalErrorUnexpected);
}

@end

