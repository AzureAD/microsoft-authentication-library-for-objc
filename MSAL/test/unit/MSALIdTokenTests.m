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
#import "MSALIdToken.h"

@interface MSALIdTokenTests : XCTestCase

@end

@implementation MSALIdTokenTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNilIdToken
{
    MSALIdToken * idToken = [[MSALIdToken alloc] initWithRawIdToken:nil];
    
    XCTAssertNil(idToken);
}

- (void)testIncompleteIdToken
{
    NSString *rawIdToken = @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9VZ3FYR190TUxkdVNKMVQ4Y2FIeFU3Y090YyJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODgyNDM0MjMsIm5iZiI6MTQ4ODI0MzQyMywiZXhwIjoxNDg4MjQ3MzIzLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiVHFnVHp6V2JWMTZtSWtJRTBzeHNSR1FGbnJPWWxBZU9ZUnhrZHlCaERGbyIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9";
    
    MSALIdToken * idToken = [[MSALIdToken alloc] initWithRawIdToken:rawIdToken];
    
    XCTAssertNil(idToken);
}

- (void)testInvalidIdToken
{
    NSString *rawIdToken = @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9VZ3FYR190TUxkdVNKMVQ4Y2FIeFU3Y090YyJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODgyNDM0MjMsIm5iZiI6MTQ4ODI0MzQyMywiZXhwIjoxNDg4MjQ3MzIzLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiVHFnVHp6V2JWMTZtSWtJ9.qw1Npo_ehA-WBE6TqpMkZuRRISOOlJ-pa_0isHBGN3OEftyPAkiVTmTFl95xH-M54epz-DjCHJ90DgLEVF7fTw9Jy7etiQaiE5dcg59J7TknPNHBsiGC2_79bs0uYwUdTVn87r1_k8dBJbDiNhA4ybRk5CyqQTjOXmu9ux5VtaGbVjdZ9W98vD_n_2hVmEJLgp_YlefNuaUBiB7Bet7XJUCJDpK7DIsZOMbl0CJ6A4hlYKiYxRahDradZJn54DbztIFHZQNPUpStE4Xo8GM5T_StmDjBN9hh4caj2ol_9bOHkOXWpetMx3wSh0EET5Elc02i2a_XR-2RWU0ENZBYPg";
    
    MSALIdToken * idToken = [[MSALIdToken alloc] initWithRawIdToken:rawIdToken];
    
    XCTAssertNil(idToken);
}

- (void)testValidIdToken
{
    NSString *rawIdToken = @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9VZ3FYR190TUxkdVNKMVQ4Y2FIeFU3Y090YyJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODgyNDM0MjMsIm5iZiI6MTQ4ODI0MzQyMywiZXhwIjoxNDg4MjQ3MzIzLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiVHFnVHp6V2JWMTZtSWtJRTBzeHNSR1FGbnJPWWxBZU9ZUnhrZHlCaERGbyIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9.qw1Npo_ehA-WBE6TqpMkZuRRISOOlJ-pa_0isHBGN3OEftyPAkiVTmTFl95xH-M54epz-DjCHJ90DgLEVF7fTw9Jy7etiQaiE5dcg59J7TknPNHBsiGC2_79bs0uYwUdTVn87r1_k8dBJbDiNhA4ybRk5CyqQTjOXmu9ux5VtaGbVjdZ9W98vD_n_2hVmEJLgp_YlefNuaUBiB7Bet7XJUCJDpK7DIsZOMbl0CJ6A4hlYKiYxRahDradZJn54DbztIFHZQNPUpStE4Xo8GM5T_StmDjBN9hh4caj2ol_9bOHkOXWpetMx3wSh0EET5Elc02i2a_XR-2RWU0ENZBYPg";
    
    MSALIdToken * idToken = [[MSALIdToken alloc] initWithRawIdToken:rawIdToken];
    
    XCTAssertEqualObjects(idToken.issuer, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(idToken.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(idToken.subject, @"TqgTzzWbV16mIkIE0sxsRGQFnrOYlAeOYRxkdyBhDFo");
    XCTAssertEqualObjects(idToken.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(idToken.version, @"2.0");
    XCTAssertEqualObjects(idToken.preferredUsername, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(idToken.name, @"Simple User");
    XCTAssertEqualObjects(idToken.homeObjectId, nil);//need to update with id token with homeObjectId
}

@end
