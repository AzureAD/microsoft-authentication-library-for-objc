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

// From NSString+MSALHelperMethods.m
#define RANDOM_STRING_MAX_SIZE 1024

@interface MSALStringHelperMethodTests : MSALTestCase

@end

@implementation MSALStringHelperMethodTests

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

- (void)testIsStringNilOrBlankNil
{
    XCTAssertTrue([NSString msalIsStringNilOrBlank:nil], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankSpace
{
    XCTAssertTrue([NSString msalIsStringNilOrBlank:@" "], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankTab
{
    XCTAssertTrue([NSString msalIsStringNilOrBlank:@"\t"], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankEnter
{
    XCTAssertTrue([NSString msalIsStringNilOrBlank:@"\r"], "Should return true for nil.");
    XCTAssertTrue([NSString msalIsStringNilOrBlank:@"\n"], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankMixed
{
    XCTAssertTrue([NSString msalIsStringNilOrBlank:@" \r\n\t  \t\r\n"], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankNonEmpty
{
    //Prefix by white space:
    NSString* str = @"  text";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @" \r\n\t  \t\r\n text";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
    
    //Suffix with white space:
    str = @"text  ";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @"text \r\n\t  \t\r\n";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
    
    //Surrounded by white space:
    str = @"text  ";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @" \r\n\t text  \t\r\n";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
    
    //No white space:
    str = @"t";
    XCTAssertFalse([NSString msalIsStringNilOrBlank:str], "Not an empty string %@", str);
}

- (void)testTrimmedString
{
    XCTAssertEqualObjects([@" \t\r\n  test" msalTrimmedString], @"test");
    XCTAssertEqualObjects([@"test  \t\r\n  " msalTrimmedString], @"test");
    XCTAssertEqualObjects([@"test  \t\r\n  test" msalTrimmedString], @"test  \t\r\n  test");
    XCTAssertEqualObjects([@"  \t\r\n  test  \t\r\n  test  \t\r\n  " msalTrimmedString], @"test  \t\r\n  test");
}

#define VERIFY_BASE64(_ORIGINAL, _EXPECTED) { \
    NSString* encoded = [_ORIGINAL msalBase64UrlEncode]; \
    NSString* decoded = [_EXPECTED msalBase64UrlDecode]; \
    XCTAssertEqualObjects(encoded, _EXPECTED); \
    XCTAssertEqualObjects(decoded, _ORIGINAL); \
}

- (void)testBase64
{
    NSString* encodeEmpty = [@"" msalBase64UrlEncode];
    XCTAssertEqualObjects(encodeEmpty, @"");
    
    NSString* decodeEmpty = [@"" msalBase64UrlDecode];
    XCTAssertEqualObjects(decodeEmpty, @"");
    
    //15 characters, aka 3k:
    NSString* test1 = @"1$)=- \t\r\nfoo%^!";
    VERIFY_BASE64(test1, @"MSQpPS0gCQ0KZm9vJV4h");
    
    //16 characters, aka 3k + 1:
    NSString* test2 = [test1 stringByAppendingString:@"@"];
    VERIFY_BASE64(test2, @"MSQpPS0gCQ0KZm9vJV4hQA");
    
    //17 characters, aka 3k + 2:
    NSString* test3 = [test2 stringByAppendingString:@"<"];
    VERIFY_BASE64(test3, @"MSQpPS0gCQ0KZm9vJV4hQDw");
    
    //Ensure that URL encoded is in place through encoding correctly the '+' and '/' signs (just in case)
    VERIFY_BASE64(@"++++/////", @"KysrKy8vLy8v");
    
    //Decode invalid:
    XCTAssertFalse([@" " msalBase64UrlDecode].length, "Contains non-suppurted character < 128");
    XCTAssertFalse([@"™" msalBase64UrlDecode].length, "Contains characters beyond 128");
    XCTAssertFalse([@"денят" msalBase64UrlDecode].length, "Contains unicode characters.");
}

- (void)testUrlFormEncodeDecode
{
    NSString* testString = @"Some interesting test/+-)(*&^%$#@!~|";
    NSString* encoded = [testString msalUrlFormEncode];
    
    XCTAssertEqualObjects(encoded, @"Some+interesting+test%2F%2B-%29%28%2A%26%5E%25%24%23%40%21~%7C");
    XCTAssertEqualObjects([encoded msalUrlFormDecode], testString);
}

- (void)testRandomUrlSafeStringOfSize
{
    // test with zero size
    NSString *stringZero = [NSString randomUrlSafeStringOfSize:0];
    XCTAssertTrue([NSString msalIsStringNilOrBlank:stringZero]);
    
    // test with normal size
    XCTAssertNotNil([NSString randomUrlSafeStringOfSize:10]);
    XCTAssertNotNil([NSString randomUrlSafeStringOfSize:100]);
    XCTAssertNotNil([NSString randomUrlSafeStringOfSize:1000]);
    XCTAssertNotNil([NSString randomUrlSafeStringOfSize:RANDOM_STRING_MAX_SIZE]);
    
    // test with bigger then max
    XCTAssertNil([NSString randomUrlSafeStringOfSize:RANDOM_STRING_MAX_SIZE + 1]);
    
}
@end
