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
#import "MSALTestLogger.h"

@interface MSALLoggerTests : MSALTestCase

@end

@implementation MSALLoggerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [[MSALTestLogger sharedLogger] reset];
}

- (void)testLogMacros
{
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelLast];
    MSALTestLogger* logger = [MSALTestLogger sharedLogger];
    
    LOG_ERROR(nil, @"Error message! %d", 0);
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"Error message! 0"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelError);
    
    [logger reset];
    LOG_WARN(nil, @"Oh no, a %@ thing happened!", @"bad");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"Oh no, a bad thing happened!"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelWarning);
    
    [logger reset];
    LOG_INFO(nil, @"This informative message has been seen %d times", 20);
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"This informative message has been seen 20 times"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelInfo);
    
    [logger reset];
    LOG_VERBOSE(nil, @"So much noise, this message is %@ useful", @"barely");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"So much noise, this message is barely useful"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelVerbose);
    
    [logger reset];
    [[MSALLogger sharedLogger] setPiiLoggingEnabled:YES];
    LOG_ERROR_PII(nil, @"userId: %@ failed to sign in", @"user@contoso.com");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"userId: user@contoso.com failed to sign in"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelError);
    
    [logger reset];
    [[MSALLogger sharedLogger] setPiiLoggingEnabled:YES];
    LOG_WARN_PII(nil, @"%@ pressed the cancel button", @"user@contoso.com");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com pressed the cancel button"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelWarning);
    
    [logger reset];
    [[MSALLogger sharedLogger] setPiiLoggingEnabled:YES];
    LOG_INFO_PII(nil, @"%@ is trying to log in", @"user@contoso.com");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com is trying to log in"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelInfo);
     
    [logger reset];
    [[MSALLogger sharedLogger] setPiiLoggingEnabled:YES];
    LOG_VERBSOE_PII(nil, @"waiting on response from %@", @"contoso.com");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"waiting on response from contoso.com"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelVerbose);
}

- (void)testIsPiiEnabled
{
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelLast];
    MSALTestLogger* logger = [MSALTestLogger sharedLogger];
    [[MSALLogger sharedLogger] setPiiLoggingEnabled:NO];
    LOG_VERBSOE_PII(nil, @"waiting on response from %@", @"contoso.com");
    XCTAssertNil(logger.lastMessage);
    
    [[MSALLogger sharedLogger] setPiiLoggingEnabled:YES];
    LOG_VERBSOE_PII(nil, @"waiting on response from %@", @"contoso.com");
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"waiting on response from contoso.com"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelVerbose);
}

- (void)testLogLevel
{
    MSALTestLogger* logger = [MSALTestLogger sharedLogger];
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelNothing];
    
    logger.lastMessage = @"dummy message";
    LOG_ERROR(nil, @"Error message! %d", 0);
    // Because we set the log level to nothing, the calback should not get hit and
    // the message should not be overriden.
    XCTAssertEqualObjects(logger.lastMessage, @"dummy message");
    
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelError];
    LOG_ERROR(nil, @"Error message! %d", 0);
    XCTAssertTrue([logger.lastMessage containsString:@"Error message! 0"]);
    
    logger.lastMessage = @"dummy message";
    LOG_WARN(nil, @"warning");
    XCTAssertEqualObjects(logger.lastMessage, @"dummy message");
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelWarning];
    LOG_WARN(nil, @"warning");
    XCTAssertTrue([logger.lastMessage containsString:@"warning"]);
    
    logger.lastMessage = @"dummy message";
    LOG_INFO(nil, @"info");
    XCTAssertEqualObjects(logger.lastMessage, @"dummy message");
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelInfo];
    LOG_INFO(nil, @"info");
    XCTAssertTrue([logger.lastMessage containsString:@"info"]);
    
    logger.lastMessage = @"dummy message";
    LOG_VERBOSE(nil, @"verbose");
    XCTAssertEqualObjects(logger.lastMessage, @"dummy message");
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelVerbose];
    LOG_VERBOSE(nil, @"verbose");
    XCTAssertTrue([logger.lastMessage containsString:@"verbose"]);
}


@end
