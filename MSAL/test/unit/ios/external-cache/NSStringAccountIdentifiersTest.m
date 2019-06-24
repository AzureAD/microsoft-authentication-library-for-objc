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
#import "NSString+MSALAccountIdenfiers.h"

@interface NSStringAccountIdentifiersTest : XCTestCase

@end

@implementation NSStringAccountIdentifiersTest

#pragma mark - msalStringAsGUID

- (void)testMsalStringAsGUID_whenLongerThan16CharsString_shouldReturnNil
{
    NSString *mylongString = @"12345678910111213141516";
    NSString *guid = [mylongString msalStringAsGUID];
    XCTAssertNil(guid);
}

- (void)testMsalStringAsGUID_when16CharsString_shouldReturnGUIDData
{
    NSString *mylongString = @"40c03bac188d01d1";
    NSString *expectedUUID = @"00000000-0000-0000-40C0-3BAC188D01D1";
    
    NSString *actualUUID = [mylongString msalStringAsGUID];
    XCTAssertNotNil(actualUUID);
    XCTAssertEqualObjects(expectedUUID.lowercaseString, actualUUID);
}

- (void)testMsalStringAsGUID_when8CharsString_shouldReturnGUIDData
{
    NSString *mylongString = @"188d01d1";
    
    NSString *actualUUID = [mylongString msalStringAsGUID];
    XCTAssertNil(actualUUID);
}

- (void)testMsalStringAsGUID_whenOddCharsString_shouldReturnGUIDData
{
    NSString *mylongString = @"188d01d";
    
    NSString *actualUUID = [mylongString msalStringAsGUID];
    XCTAssertNil(actualUUID);
}

- (void)testMsalStringAsGUID_whenEmptyCharsString_shouldReturnGUIDDataFilledWithZeroes
{
    NSString *myEmptyString = @"";
    NSString *actualUUID = [myEmptyString msalStringAsGUID];
    XCTAssertNil(actualUUID);
}

#pragma mark - msalStringAsGUIDData

- (void)testMSALStringASGUIDData_whenLongerThan16CharsString_shouldReturnNil
{
    NSString *mylongString = @"12345678910111213141516";
    NSData *guidData = [mylongString msalStringAsGUIDData];
    XCTAssertNil(guidData);
}

- (void)testMSALStringAsGUIDData_when16CharsString_shouldReturnGUIDData
{
    NSString *mylongString = @"40c03bac188d01d1";
    NSString *expectedUUID = @"00000000-0000-0000-40C0-3BAC188D01D1";
    
    NSData *guidData = [mylongString msalStringAsGUIDData];
    XCTAssertNotNil(guidData);
    NSUUID *actualUUID = [[NSUUID alloc] initWithUUIDBytes:[guidData bytes]];
    XCTAssertNotNil(actualUUID);
    XCTAssertEqualObjects(expectedUUID, actualUUID.UUIDString);
}

- (void)testMSALStringAsGUIDData_when8CharsString_shouldReturnGUIDData
{
    NSString *mylongString = @"188d01d1";
    NSString *expectedUUID = @"00000000-0000-0000-0000-0000188D01D1";
    
    NSData *guidData = [mylongString msalStringAsGUIDData];
    XCTAssertNotNil(guidData);
    NSUUID *actualUUID = [[NSUUID alloc] initWithUUIDBytes:[guidData bytes]];
    XCTAssertNotNil(actualUUID);
    XCTAssertEqualObjects(expectedUUID, actualUUID.UUIDString);
}

- (void)testMSALStringAsGUIDData_whenOddCharsString_shouldReturnGUIDData
{
    NSString *mylongString = @"188d01d";
    NSString *expectedUUID = @"00000000-0000-0000-0000-00000188D01D";
    
    NSData *guidData = [mylongString msalStringAsGUIDData];
    XCTAssertNotNil(guidData);
    NSUUID *actualUUID = [[NSUUID alloc] initWithUUIDBytes:[guidData bytes]];
    XCTAssertNotNil(actualUUID);
    XCTAssertEqualObjects(expectedUUID, actualUUID.UUIDString);
}

- (void)testMSALStringAsGUIDData_whenEmptyCharsString_shouldReturnGUIDDataFilledWithZeroes
{
    NSString *myEmptyString = @"";
    NSString *expectedUUID = @"00000000-0000-0000-0000-000000000000";
    NSData *guidData = [myEmptyString msalStringAsGUIDData];
    XCTAssertNotNil(guidData);
    NSUUID *actualUUID = [[NSUUID alloc] initWithUUIDBytes:[guidData bytes]];
    XCTAssertNotNil(actualUUID);
    XCTAssertEqualObjects(expectedUUID, actualUUID.UUIDString);
}

#pragma mark - msalGUIDAsShortString

- (void)testMSALGUIDAsShortString_whenIncorrectGUID_shouldReturnNil
{
    NSString *input = @"xxkidkddndnjdj";
    NSString *output = [input msalGUIDAsShortString];
    XCTAssertNil(output);
}

- (void)testMSALGUIDAsShortString_whenEmptyGUID_shouldReturnNil
{
    NSString *input = @"";
    NSString *output = [input msalGUIDAsShortString];
    XCTAssertNil(output);
}

- (void)testMSALGUIDAsShortString_whenOddCharsString_shouldReturnCorrectString
{
    NSString *expectedResult = @"188d01d";
    NSString *input = @"00000000-0000-0000-0000-00000188D01D";
    
    NSString *result = [input msalGUIDAsShortString];
    XCTAssertEqualObjects(result, expectedResult);
}

- (void)testMSALGUIDAsShortString_when16CharsString_shouldReturnCorrectString
{
    NSString *expectedResult = @"40c03bac188d01d1";
    NSString *input = @"00000000-0000-0000-40C0-3BAC188D01D1";
    
    NSString *result = [input msalGUIDAsShortString];
    XCTAssertEqualObjects(result, expectedResult);
}

- (void)testMSALGUIDAsShortString_when8CharsString_shouldReturnCorrectString
{
    NSString *expectedResult = @"188d01d1";
    NSString *input = @"00000000-0000-0000-0000-0000188D01D1";
    
    NSString *result = [input msalGUIDAsShortString];
    XCTAssertEqualObjects(result, expectedResult);
}

@end
