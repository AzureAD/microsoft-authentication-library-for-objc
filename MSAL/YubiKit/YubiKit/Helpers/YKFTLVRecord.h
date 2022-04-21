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

#ifndef TLVRecord_h
#define TLVRecord_h


typedef UInt64 YKFTLVTag;

@interface YKFTLVRecord : NSObject

/// Tag for the record.
@property (nonatomic, readonly) YKFTLVTag tag;

/// Value of the record.
@property (nonatomic, readonly) NSData * _Nonnull value;

/// NSData representation for the encoded record.
@property (nonatomic, readonly) NSData * _Nonnull data;

/// Creates a YKFTLVRecord record with a tag and value.
/// @param tag tag for the record.
/// @param value value for the record.
/// @return YKFTLVRecord
- (instancetype _Nonnull )initWithTag:(YKFTLVTag)tag value:(NSData *_Nonnull)value;

/// Creates YKFTLVRecord with tag and an array of TKTLVRecord instances as subrecords.
/// @param tag tag value for the new record.
/// @param records array of BERTLVRecord instances.
/// @return YKFTLVRecord
- (instancetype _Nonnull )initWithTag:(YKFTLVTag)tag records:(NSArray<YKFTLVRecord *> *_Nonnull)records;

/// Parses YKFTLVRecord from data
/// @param data NSData containing a serialized form of a BERTLV record.
/// @return a YKFTLVRecord or nil if it was not possible to parse the supplied data.
+ (nullable instancetype)recordFromData:(NSData *_Nullable)data;

/// Parses a sequence of serialized YKFTLVRecord from a NSData object.
/// @param data NSData object containing serialized representatins of one or more BERTLV records.
/// @return An array of YKFTLVRecord instances parsed from input data block or nil if data do not form valid BERTLV record sequence.
+ (nullable NSArray<YKFTLVRecord *> *)sequenceOfRecordsFromData:(NSData *_Nullable)data;

- (instancetype _Nonnull )init NS_UNAVAILABLE;

@end

#endif /* YKFTLVRecord_h */
