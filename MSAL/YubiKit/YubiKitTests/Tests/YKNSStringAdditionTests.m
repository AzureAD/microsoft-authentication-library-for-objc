//
//  YKNSStringAdditionTests.m
//  YubiKitTests
//
//  Created by Irina Rakhmanova on 2/10/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "YKFNSStringAdditions.h"

@interface YKFNSStringAdditionsTests : XCTestCase
@end

@implementation YKFNSStringAdditionsTests

- (void)test_WhenKeyContainsSlashAndPeriodExists_PeriodIsParsed {
    NSString *credentialKey = @"60/Yubico:account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertEqual(period, 60, @"");
    XCTAssertTrue([label isEqualToString:@"Yubico:account@gmail.com"], @"");
}

- (void)test_WhenKeyContainsSlashAndPeriodNotExists_PeriodIsZero {
    NSString *credentialKey = @"/Yubico:account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertEqual(period, 0, @"");
    XCTAssertTrue([label isEqualToString:@"/Yubico:account@gmail.com"], @"");
}

- (void)test_WhenKeyContainsSlashInTheMiddleOfText_PeriodIsZero {
    NSString *credentialKey = @"Yubico/demo:account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertEqual(period, 0, @"");
    XCTAssertTrue([label isEqualToString:@"Yubico/demo:account@gmail.com"], @"");
}

- (void)test_WhenKeyContainsSlashAndPeriodExistsAndIssuerNotExists_PeriodIsParsedAndIssuerIsNilAndAccountIsParsed {
    NSString *credentialKey = @"60/account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNil(issuer, @"Issuer parsed as nil");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"account@gmail.com"], @"");
    XCTAssertTrue([account isEqualToString:@"account@gmail.com"], @"");
    XCTAssertEqual(period, 60, @"");
}

- (void)test_WhenKeyPeriodNotExistsAndIssuerNotExists_PeriodIsZeroAndIssuerIsNilAndAccountIsParsed {
    NSString *credentialKey = @"account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNil(issuer, @"Issuer parsed as nil");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"account@gmail.com"], @"");
    XCTAssertTrue([account isEqualToString:@"account@gmail.com"], @"");
    XCTAssertEqual(period, 0, @"");
}

- (void)test_WhenKeyAccountContainsColonAndPeriodNotExistsAndIssuerNotExists_PeriodIsZeroAndLableIsParsed {
    NSString *credentialKey = @":account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@":account@gmail.com"], @"");
    XCTAssertTrue([issuer isEqualToString:@""], @"");
    XCTAssertTrue([account isEqualToString:@"account@gmail.com"], @"");
    XCTAssertEqual(period, 0, @"");
}

- (void)test_WhenKeyPeriodNotExistsAndIssuerContainsColon_PeriodIsZeroAndLableIsParsedByLastColon {
    NSString *credentialKey = @"Yubico:demo:account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"Yubico:demo:account@gmail.com"], @"");
    XCTAssertTrue([issuer isEqualToString:@"Yubico:demo"], @"");
    XCTAssertTrue([account isEqualToString:@"account@gmail.com"], @"");
    XCTAssertEqual(period, 0, @"");
}

- (void)test_WhenKeyPeriodExistsAndIssuerContainsColon_PeriodIsParsedAndLableIsParsedByLastColon {
    NSString *credentialKey = @"15/Yubico:demo:account@gmail.com";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"Yubico:demo:account@gmail.com"], @"");
    XCTAssertTrue([issuer isEqualToString:@"Yubico:demo"], @"");
    XCTAssertTrue([account isEqualToString:@"account@gmail.com"], @"");
    XCTAssertEqual(period, 15, @"");
}

- (void)test_WhenKeyPeriodNotExistsAndAccountContainsSlash_PeriodIsZeroAndLableIsParsedByColon {
    NSString *credentialKey = @"YubicoDemo:account/test";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"YubicoDemo:account/test"], @"");
    XCTAssertTrue([issuer isEqualToString:@"YubicoDemo"], @"");
    XCTAssertTrue([account isEqualToString:@"account/test"], @"");
    XCTAssertEqual(period, 0, @"");
}

- (void)test_WhenKeyPeriodNotExistsAndIssuerContainsSlashAndAccountContainsSlash_PeriodIsZeroAndLableIsParsedByColon {
    NSString *credentialKey = @"Yubico/demo:account/test";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"Yubico/demo:account/test"], @"");
    XCTAssertTrue([issuer isEqualToString:@"Yubico/demo"], @"");
    XCTAssertTrue([account isEqualToString:@"account/test"], @"");
    XCTAssertEqual(period, 0, @"");
}

- (void)test_WhenKeyPeriodExistsAndAccountContainsSlash_PeriodIsParsedAndLableIsParsedByColon {
    NSString *credentialKey = @"15/YubicoDemo:account/test";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"YubicoDemo:account/test"], @"");
    XCTAssertTrue([issuer isEqualToString:@"YubicoDemo"], @"");
    XCTAssertTrue([account isEqualToString:@"account/test"], @"");
    XCTAssertEqual(period, 15, @"");
}

- (void)test_WhenKeyPeriodExistsAndIssuerContainsSlashAndAccountContainsSlash_PeriodIsParsedAndLableIsParsedByColon {
    NSString *credentialKey = @"15/Yubico/demo:account/test";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"Yubico/demo:account/test"], @"");
    XCTAssertTrue([issuer isEqualToString:@"Yubico/demo"], @"");
    XCTAssertTrue([account isEqualToString:@"account/test"], @"");
    XCTAssertEqual(period, 15, @"");
}

- (void)test_WhenKeyPeriodNotExistsAccountContainsColon_PeriodIsZeroAndLableIsParsedByLastColon {
    NSString *credentialKey = @"Yubico Demo:account:test";

    NSUInteger period = 0;
    NSString *issuer = nil;
    NSString *account = nil;
    NSString *label = nil;

    [credentialKey ykf_OATHKeyExtractPeriod: &period issuer: &issuer account: &account label: &label];
    XCTAssertNotNil(issuer, @"Issuer is parsed");
    XCTAssertNotNil(account, @"Account is parsed");
    XCTAssertTrue([label isEqualToString:@"Yubico Demo:account:test"], @"");
    XCTAssertTrue([issuer isEqualToString:@"Yubico Demo:account"], @"");
    XCTAssertTrue([account isEqualToString:@"test"], @"");
    XCTAssertEqual(period, 0, @"");
}

@end

