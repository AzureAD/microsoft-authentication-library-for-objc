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

#import <XCTest/XCTest.h>
#import "MSALLogMask.h"

@interface MSALLogMaskTests : XCTestCase

@end

@implementation MSALLogMaskTests

- (void)setUp
{
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [super setUp];
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Correctness

- (void)testMaskPII_returnsCorrect_onNotNil
{
    NSString* string = [[MSALLogMask maskPII:@"Test"] description];
    XCTAssertEqualObjects(string, @"Masked(not-null)");
    XCTAssertTrue([string isEqualToString:@"Masked(not-null)"]);
}

- (void)testMaskPII_returnsCorrect_onNil
{
    NSString* string = [[MSALLogMask maskPII:nil] description];
    XCTAssertEqualObjects(string, @"Masked(null)");
    XCTAssertTrue([string isEqualToString:@"Masked(null)"]);
}

- (void)testMaskPII_returnsCorrect_onNotNil_andNotMaksed
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskEUIIOnly;
    NSString* string = [[MSALLogMask maskPII:@"Test"] description];
    XCTAssertEqualObjects(string, @"Test");
    XCTAssertTrue([string isEqualToString:@"Test"]);
}

- (void)testMaskEUII_returnsCorrect_onNotNil
{
    NSString* string = [[MSALLogMask maskEUII:@"UserAccountDummy"] description];
    XCTAssertEqualObjects(string, @"Masked(not-null)");
    XCTAssertTrue([string isEqualToString:@"Masked(not-null)"]);
}

- (void)testMaskEUII_returnsCorrect_onNill
{
    NSString* string = [[MSALLogMask maskEUII:nil] description];
    XCTAssertEqualObjects(string, @"Masked(null)");
    XCTAssertTrue([string isEqualToString:@"Masked(null)"]);
}

- (void)testMaskEUII_returnsCorrect_onNotNil_andNotMaksed
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    NSString* string = [[MSALLogMask maskEUII:@"Test"] description];
    XCTAssertEqualObjects(string, @"Test");
    XCTAssertTrue([string isEqualToString:@"Test"]);
}

- (void) testMaskHashable_returnsCorrect_onNotNil
{
    NSString* string = [[MSALLogMask maskTrackablePII:@"HomeAccountId"] description];
    XCTAssertEqualObjects(string, @"d87b613d");
    XCTAssertTrue([string isEqualToString:@"d87b613d"]);
}

- (void) testMaskHashable_returnsCorrect_onNil
{
    NSString* string = [[MSALLogMask maskTrackablePII:nil] description];
    XCTAssertEqualObjects(string, @"Masked(null)");
    XCTAssertTrue([string isEqualToString:@"Masked(null)"]);
}

- (void) testMaskHashable_returnsCorrect_onNotNil_andNotMaksed
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskEUIIOnly;
    NSString* string = [[MSALLogMask maskTrackablePII:@"HomeAccountId"] description];
    XCTAssertEqualObjects(string, @"HomeAccountId");
    XCTAssertTrue([string isEqualToString:@"HomeAccountId"]);
}

- (void) testMaskUsername_returnsCorrect_onNotNil
{
    NSString* string = [[MSALLogMask maskUsername:@"user@contoso.com"] description];
    XCTAssertEqualObjects(string, @"auth.placeholder-04f8996d__contoso.com");
    XCTAssertTrue([string isEqualToString:@"auth.placeholder-04f8996d__contoso.com"]);
}

- (void) testMaskUsername_returnsCorrect_onNil
{
    NSString* string = [[MSALLogMask maskUsername:nil] description];
    XCTAssertEqualObjects(string, @"Masked(null)");
    XCTAssertTrue([string isEqualToString:@"Masked(null)"]);
}

- (void) testMaskUsernamereturnsCorrect_onNotNil_andNotMaksed
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    NSString* string = [[MSALLogMask maskUsername:@"user@contoso.com"] description];
    XCTAssertEqualObjects(string, @"user@contoso.com");
    XCTAssertTrue([string isEqualToString:@"user@contoso.com"]);
}

#pragma mark - Macro

- (void) testMaskPII_returnsSameAsMacro
{
    NSString* string = [[MSALLogMask maskPII:@"Test"] description];
    XCTAssertEqualObjects(string, [MSID_PII_LOG_MASKABLE(@"Test") description]);
    XCTAssertTrue([string isEqualToString:[MSID_PII_LOG_MASKABLE(@"Test") description]]);
}

- (void) testMaskEUII_returnsSameAsMacro
{
    NSString* string = [[MSALLogMask maskEUII:@"Test"] description];
    XCTAssertEqualObjects(string, [MSID_EUII_ONLY_LOG_MASKABLE(@"Test") description]);
    XCTAssertTrue([string isEqualToString:[MSID_EUII_ONLY_LOG_MASKABLE(@"Test") description]]);
}

- (void) testMaskHashable_returnsSameAsMacro
{
    NSString* string = [[MSALLogMask maskTrackablePII:@"HomeAccountId"] description];
    XCTAssertEqualObjects(string, [MSID_PII_LOG_TRACKABLE(@"HomeAccountId") description]);
    XCTAssertTrue([string isEqualToString:[MSID_PII_LOG_TRACKABLE(@"HomeAccountId") description]]);
}

- (void) testMaskUsername_returnsSameAsMacro
{
    NSString* string = [[MSALLogMask maskUsername:@"user@contoso.com"] description];
    XCTAssertEqualObjects(string, [MSID_PII_LOG_EMAIL(@"user@contoso.com") description]);
    XCTAssertTrue([string isEqualToString:[MSID_PII_LOG_EMAIL(@"user@contoso.com") description]]);
}

@end
