// Copyright 2018-2022 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import "YKFTLVRecord.h"
#import "YKFNSDataAdditions+Private.h"

@interface YKFTLVRecord()
@property (nonatomic, readwrite) YKFTLVTag tag;
@property (nonatomic, readwrite) NSData *value;
@end

@interface NSData (NSData_ByteEncoding)
    + (NSData *)ykf_dataWithBytesStripLeadingZeros:(char*)bytes length:(NSUInteger)length;
@end

@implementation YKFTLVRecord

+ (nullable instancetype)recordFromData:(NSData *_Nullable)data checkMatchingLength:(Boolean)checkMatchingLength bytesRead:(NSUInteger*)bytesRead {
    *bytesRead = 0;
    
    // tag
    if (data.length == 0) {
        return nil;
    }
    Byte *bytes = (Byte *)data.bytes;
    NSUInteger offset = 0;
    YKFTLVTag tag = bytes[offset++];
    if ((tag & 0x1F) == 0x1F) {
        if (data.length < 2) { return nil; }
        tag = (tag << 8) | (bytes[offset++] & 0xFF);
        while ((tag & 0x80) == 0x80 && offset < data.length) {
            if (offset >= sizeof(YKFTLVTag)) { return nil; }
            tag = (tag << 8) | (bytes[offset++] & 0xFF);
        }
    }
    
    // length
    if (offset > data.length) { return nil; }
    NSUInteger length = bytes[offset++];
    if (length == 0x80) {
        return nil;
    } else if (length > 0x80) {
        NSUInteger lengthOfLength = length - 0x80;
        length = 0;
        if (lengthOfLength > sizeof(length) || data.length < offset + lengthOfLength) {
            return nil;
        }
        for (int i = 0; i < lengthOfLength; i++) {
            length = (length << 8) | (bytes[offset++] & 0xFF);
        }
    }
    
    // data
    if (checkMatchingLength && data.length != offset + length) {
        return nil;
    }
    if (data.length < offset + length || offset + length < length) {
        return nil;
    }
    *bytesRead = offset + length;
    return [[YKFTLVRecord alloc] initWithTag:tag value:[data subdataWithRange:NSMakeRange(offset, length)]];
}

- (NSData *)data {

    NSMutableData * result = [NSMutableData new];
    
    // tag
    YKFTLVTag tag = CFSwapInt64HostToBig(self.tag);
    char* tagBytes = (char*) &tag;
    NSData *tagData = [NSData ykf_dataWithBytesStripLeadingZeros:tagBytes length:sizeof(YKFTLVTag)];
    [result appendData:tagData];
    
    // length
    NSUInteger hostLength = self.value.length;
    if (hostLength < 0x80) {
        [result appendBytes:&hostLength length:1];
    } else {
        NSUInteger length = NSSwapHostLongToBig(hostLength);
        char* lengthBytes = (char*)&length;
        NSData *lengthData = [NSData ykf_dataWithBytesStripLeadingZeros:lengthBytes length:sizeof(length)];
        Byte lengthHeader = 0x80 | lengthData.length;
        [result appendBytes:&lengthHeader length:1];
        [result appendData:lengthData];
    }
    
    // data
    [result appendData:self.value];

    return result;
}

- (instancetype _Nonnull )initWithTag:(YKFTLVTag)tag value:(NSData *_Nonnull)value {
    self = [super init];
    if (self) {
        self.tag = tag;
        self.value = value;
    }
    return self;
}

- (instancetype _Nonnull )initWithTag:(YKFTLVTag)tag records:(NSArray<YKFTLVRecord *> *_Nonnull)records {
    NSMutableData *data = [NSMutableData new];
    for (YKFTLVRecord * record in records) {
        [data appendData:record.data];
    }
    return [[YKFTLVRecord alloc] initWithTag:tag value:data];
}

+ (nullable instancetype)recordFromData:(NSData *_Nullable)data {
    NSUInteger bytesRead = 0;
    return [self recordFromData:data checkMatchingLength:true bytesRead:&bytesRead];
}

+ (nullable NSArray<YKFTLVRecord *> *)sequenceOfRecordsFromData:(NSData *_Nullable)data {
    
    NSMutableArray<YKFTLVRecord *> *records = [[NSMutableArray<YKFTLVRecord *> alloc] init];
    
    NSUInteger location = 0;
    bool keepScanning = true;
    while (keepScanning) {
        data = [data subdataWithRange:NSMakeRange(location, data.length - location)];
        
        NSUInteger bytesRead = 0;
        YKFTLVRecord *record = [YKFTLVRecord recordFromData:data checkMatchingLength:NO bytesRead:&bytesRead];
        if (record) {
            [records addObject:record];
            location = bytesRead;
            if (location > data.length) {
                records = nil;
                keepScanning = NO;
            }
            if (location == data.length) {
                keepScanning = NO;
            }
        } else {
            records = nil;
            keepScanning = NO;
        }
    }
    return records;
}

@end


@implementation NSData (NSData_ByteEncoding)
    
+ (NSData *)ykf_dataWithBytesStripLeadingZeros:(char*)bytes length:(NSUInteger)length {
    int skippedBytes = 0;
    for (int i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            skippedBytes++;
        } else {
            break;
        }
    }
    return [[NSData alloc] initWithBytes:&bytes[skippedBytes] length:length - skippedBytes];
}

@end
