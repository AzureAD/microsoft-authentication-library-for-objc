//
//  YKFTLVRecordTests.m
//  YubiKitTests
//
//  Created by Jens Utbult on 2022-02-01.
//  Copyright © 2022 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "YKFTestCase.h"
#import "YKFTLVRecord.h"

@interface YKFTLVRecordTests: YKFTestCase
@end

@implementation YKFTLVRecordTests

- (void)test_recordFromData {
    NSData *shortRecordData = [NSData dataFromHexString:@"1e03112233"];
    YKFTLVRecord *shortRecord = [YKFTLVRecord recordFromData:shortRecordData];
    XCTAssert([shortRecord.data isEqual:shortRecordData]);
    
    NSData *longRecordData = [NSData dataFromHexString:@"1e81a8112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff"];
    YKFTLVRecord *longRecord = [YKFTLVRecord recordFromData:longRecordData];
    XCTAssert([longRecord.data isEqual:longRecordData]);

    NSData *veryLongRecordData = [NSData dataFromHexString:@"a18202a0112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff"];
    YKFTLVRecord *veryLongRecord = [YKFTLVRecord recordFromData:veryLongRecordData];
    XCTAssert([veryLongRecord.data isEqual:veryLongRecordData]);
    
    NSData *longTagData = [NSData dataFromHexString:@"7f498188818180bb5c424c1b3121cf630cbcbaf60fa91e53786d1ab9e8b6e5855acb9afbec944555481d88fcd8e32947f7696d80a8f4df55be51dcb967fc5ef3d213a971a11fee54917cbe10d4b6ba69a71ee1434ce6b6cadb46ceff0bbf2ba832cb5516af35a1debf182e0a57544a64bfe2d0f711cf94dffb44dda9d1d4a9abdf1460e783b6f18203010001"];
    YKFTLVRecord *longTagRecord = [YKFTLVRecord recordFromData:longTagData];
    XCTAssert([longTagRecord.data isEqual:longTagData]);
}

- (void)test_maxLengthTag {
    NSData *data = [NSData dataFromHexString:@"DF81818181818101 03 303132"];
    YKFTLVRecord *record = [YKFTLVRecord recordFromData:data];
    XCTAssert(record != nil);
    XCTAssertEqual(record.tag, 0xDF81818181818101);
}

- (void)test_toBigTag {
    NSData *data = [NSData dataFromHexString:@"DF8181818181818101 03 303132"];
    YKFTLVRecord *record = [YKFTLVRecord recordFromData:data];
    XCTAssertNil(record);
}

- (void)test_recordFromDataNoValue {
   NSData *shortRecordData = [NSData dataFromHexString:@"1e00"];
   YKFTLVRecord *shortRecord = [YKFTLVRecord recordFromData:shortRecordData];
   XCTAssert([shortRecord.data isEqual:shortRecordData]);
}

- (void)test_recordInitalizer {
    YKFTLVRecord *record = [[YKFTLVRecord alloc] initWithTag:0xa1 value:[NSData dataFromHexString:@"11223344"]];
    NSData *expected = [NSData dataFromHexString:@"a10411223344"];
    XCTAssert([record.data isEqual:expected]);

    YKFTLVRecord *longRecord = [[YKFTLVRecord alloc] initWithTag:0xa1 value:[NSData dataFromHexString:@"112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff"]];
    NSData *expectedLong = [NSData dataFromHexString:@"a181a8112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff"];
    XCTAssert([longRecord.data isEqual:expectedLong]);
    
    YKFTLVRecord *recordWithLongTag = [[YKFTLVRecord alloc] initWithTag:0x7f49 value:[NSData dataFromHexString:@"11223344"]];
    XCTAssert([recordWithLongTag.data isEqual:[NSData dataFromHexString:@"7f490411223344"]]);
}

- (void)test_recordFromToLongData {
    // value is one byte to long
    NSData *shortRecordData = [NSData dataFromHexString:@"1e0311223344"];
    YKFTLVRecord *shortRecord = [YKFTLVRecord recordFromData:shortRecordData];
    XCTAssert(shortRecord == nil);
    NSData *longRecordData = [NSData dataFromHexString:@"1e81a8112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff11"];
    YKFTLVRecord *longRecord = [YKFTLVRecord recordFromData:longRecordData];
    XCTAssert(longRecord == nil);
}

- (void)test_recordFromToShortData {
    // value is one byte to short
    NSData *shortRecordData = [NSData dataFromHexString:@"1e031122"];
    YKFTLVRecord *shortRecord = [YKFTLVRecord recordFromData:shortRecordData];
    XCTAssert(shortRecord == nil);
    // value is one byte to short
    NSData *longRecordData = [NSData dataFromHexString:@"1e81a8112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccdd"];
    YKFTLVRecord *longRecord = [YKFTLVRecord recordFromData:longRecordData];
    XCTAssert(longRecord == nil);
}

- (void)test_malformedLength {
    NSData *data = [NSData dataFromHexString:@"DF820A 80 303132"];
    YKFTLVRecord *record = [YKFTLVRecord recordFromData:data];
    XCTAssertNil(record);
}

- (void)test_toBigLength {
    NSData *data = [NSData dataFromHexString:@"DF820A 89 303132"];
    YKFTLVRecord *record = [YKFTLVRecord recordFromData:data];
    XCTAssertNil(record);
}

-  (void)test_recordFromDataWithOutOfBoundsLength {
    // this will force the value length calculation to go out of bounds unless checked
    YKFTLVRecord *record = [YKFTLVRecord recordFromData:[NSData dataFromHexString:@"a1852233"]];
    XCTAssert(record == nil);
}

- (void)test_recordFromDataWithMissingValue {
    NSData *shortRecordData = [NSData dataFromHexString:@"1e03"];
    YKFTLVRecord *shortRecord = [YKFTLVRecord recordFromData:shortRecordData];
    XCTAssert(shortRecord == nil);
    NSData *longRecordData = [NSData dataFromHexString:@"1e81a8"];
    YKFTLVRecord *longRecord = [YKFTLVRecord recordFromData:longRecordData];
    XCTAssert(longRecord == nil);
}

-  (void)test_recordFromDataWithZeroByteInTag {
    YKFTLVRecord *record = [[YKFTLVRecord alloc] initWithTag:0x110011 value:[NSData dataFromHexString:@"112233"]];
    XCTAssert([record.data isEqual:[NSData dataFromHexString:@"11001103112233"]]);
}

- (void)test_sequenceOfRecordsFromData {
    NSData *singleRecordData = [NSData dataFromHexString:@"1e03112233"];
    NSArray<YKFTLVRecord *> *singleRecords = [YKFTLVRecord sequenceOfRecordsFromData:singleRecordData];
    XCTAssert([singleRecords.firstObject.data isEqualToData:singleRecordData]);
    XCTAssertEqual(singleRecords.count, 1);

    NSData *multipleRecordData = [NSData dataFromHexString:@"1e031122331e031122331e031122331e03112233"];
    NSArray<YKFTLVRecord *> *multipleRecords = [YKFTLVRecord sequenceOfRecordsFromData:multipleRecordData];
    XCTAssert([multipleRecords.firstObject.data isEqualToData:singleRecordData]);
    XCTAssertEqual(multipleRecords.count, 4);
}

- (void)test_sequenceOfRecordsFromMixedData {
      NSData *recordData = [NSData dataFromHexString:@"1e03112233 a000 0f81a8112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff 1c03112233 a003112233 1200"];
    NSArray<YKFTLVRecord *> *records = [YKFTLVRecord sequenceOfRecordsFromData:recordData];
    XCTAssertEqual(records.count, 6);
    XCTAssertEqual(records[0].tag, 0x1e);
    XCTAssertEqual(records[1].tag, 0xa0);
    XCTAssertEqual(records[2].tag, 0x0f);
    XCTAssert([records[2].data isEqual:[NSData dataFromHexString:@"0f81a8112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff112233445566778899aabbccddff"]]);
    XCTAssertEqual(records[3].tag, 0x1c);
    XCTAssertEqual(records[4].tag, 0xa0);
    XCTAssertEqual(records[5].tag, 0x12);
    XCTAssert([records[5].data isEqual:[NSData dataFromHexString:@"1200"]]);}

- (void)test_sequenceOfRecordsFromBadData {
    // one byte to long
    NSData *singleRecordData = [NSData dataFromHexString:@"1e0311223344"];
    NSArray<YKFTLVRecord *> *singleRecords = [YKFTLVRecord sequenceOfRecordsFromData:singleRecordData];
    XCTAssert(singleRecords == nil);

    // third record is one byte short
    NSData *multipleRecordData1 = [NSData dataFromHexString:@"1e03112233 1e03112233 1e031122 1e03112233"];
    NSArray<YKFTLVRecord *> *multipleRecords1 = [YKFTLVRecord sequenceOfRecordsFromData:multipleRecordData1];
    XCTAssert(multipleRecords1 == nil);
    
    // third record is one byte to long
    NSData *multipleRecordData2 = [NSData dataFromHexString:@"1e03112233 1e03112233 1e0311223344 1e03112233"];
    NSArray<YKFTLVRecord *> *multipleRecords2 = [YKFTLVRecord sequenceOfRecordsFromData:multipleRecordData2];
    XCTAssert(multipleRecords2 == nil);
}

@end
