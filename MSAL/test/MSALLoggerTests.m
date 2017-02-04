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

@interface MSALLoggerTests : XCTestCase

@end

static NSString *s_message = nil;
static MSALLogLevel s_level = -1;
static BOOL s_isPII = false;

@implementation MSALLoggerTests

- (void)resetLogVars
{
    s_message = nil;
    s_level = -1;
    s_isPII = false;
}

- (void)setUp
{
    [super setUp];
    
    [[MSALLogger sharedLogger] setCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII) {
        s_message = message;
        s_level = level;
        s_isPII = containsPII;
    }];
}

- (void)tearDown
{
    [super tearDown];
    [self resetLogVars];
}

- (void)testLogMacros
{
    LOG_ERROR(nil, @"Error message! %d", 0);
    XCTAssertNotNil(s_message);
    XCTAssertFalse(s_isPII);
    XCTAssertTrue([s_message containsString:@"Error message! 0"]);
    XCTAssertEqual(s_level, MSALLogLevelError);
    
    [self resetLogVars];
    
    LOG_WARN(nil, @"Oh no, a %@ thing happened!", @"bad");
    XCTAssertNotNil(s_message);
    XCTAssertFalse(s_isPII);
    XCTAssertTrue([s_message containsString:@"Oh no, a bad thing happened!"]);
    XCTAssertEqual(s_level, MSALLogLevelWarning);
    [self resetLogVars];
    
    LOG_INFO(nil, @"This informative message has been seen %d times", 20);
    XCTAssertNotNil(s_message);
    XCTAssertFalse(s_isPII);
    XCTAssertTrue([s_message containsString:@"This informative message has been seen 20 times"]);
    XCTAssertEqual(s_level, MSALLogLevelInfo);
    [self resetLogVars];
    
    LOG_VERBOSE(nil, @"So much noise, this message is %@ useful", @"barely");
    XCTAssertNotNil(s_message);
    XCTAssertFalse(s_isPII);
    XCTAssertTrue([s_message containsString:@"So much noise, this message is barely useful"]);
    XCTAssertEqual(s_level, MSALLogLevelVerbose);
    [self resetLogVars];
    
    LOG_ERROR_PII(nil, @"userId: %@ failed to sign in", @"user@contoso.com");
    XCTAssertNotNil(s_message);
    XCTAssertTrue(s_isPII);
    XCTAssertTrue([s_message containsString:@"userId: user@contoso.com failed to sign in"]);
    XCTAssertEqual(s_level, MSALLogLevelError);
    [self resetLogVars];
    
    LOG_WARN_PII(nil, @"%@ pressed the cancel button", @"user@contoso.com");
    XCTAssertNotNil(s_message);
    XCTAssertTrue(s_isPII);
    XCTAssertTrue([s_message containsString:@"user@contoso.com pressed the cancel button"]);
    XCTAssertEqual(s_level, MSALLogLevelWarning);
    [self resetLogVars];
    
    LOG_INFO_PII(nil, @"%@ is trying to log in", @"user@contoso.com");
    XCTAssertNotNil(s_message);
    XCTAssertTrue(s_isPII);
    XCTAssertTrue([s_message containsString:@"user@contoso.com is trying to log in"]);
    XCTAssertEqual(s_level, MSALLogLevelInfo);
    [self resetLogVars];
    
    LOG_VERBSOE_PII(nil, @"waiting on response from %@", @"contoso.com");
    XCTAssertNotNil(s_message);
    XCTAssertTrue(s_isPII);
    XCTAssertTrue([s_message containsString:@"waiting on response from contoso.com"]);
    XCTAssertEqual(s_level, MSALLogLevelVerbose);
    [self resetLogVars];
}


@end
