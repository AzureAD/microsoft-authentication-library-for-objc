//
//  YKFNSDataAdditionsTests.m
//  YubiKitTests
//
//  Created by Irina Rakhmanova on 3/23/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "YKFNSDataAdditions.h"

@interface YKFNSDataAdditionsTests : XCTestCase
@end

@implementation YKFNSDataAdditionsTests

- (void)test_WhenSecretContainsAllSymbolsFromTheTable_ObjectNotNil {
    NSString *secret = @"Test";
    NSData *result = [NSData ykf_dataWithBase32String: secret];
    
    XCTAssertNotNil(result, @"Returned data object from a Base32 encoded string");
}

- (void)test_WhenSecretContainsPaddingAndSymbolsFromTheTable_ObjectNotNil {
    NSString *secret = @"a2=";
    NSData *result = [NSData ykf_dataWithBase32String: secret];
    
    XCTAssertNotNil(result, @"Returned data object from a Base32 encoded string");
}

- (void)test_WhenSecretContainsSomeSymbolsNotFromTheTableAndSomeNot_ObjectNil {
    NSString *secret = @"AAA111";
    NSData *result = [NSData ykf_dataWithBase32String: secret];
    
    XCTAssertNil(result, @"Returned nil because the secret contains symbol that could not be decoded");
}

- (void)test_WhenSecretContainsNumbersNotFromTheTable_ObjectNil {
    NSString *secret = @"0189";
    NSData *result = [NSData ykf_dataWithBase32String: secret];
    
    XCTAssertNil(result, @"Returned nil because the secret contains symbol that could not be decoded");
}

@end
