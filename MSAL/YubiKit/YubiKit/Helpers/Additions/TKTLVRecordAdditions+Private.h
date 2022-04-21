// Copyright 2018-2021 Yubico AB
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

#ifndef TKTLVRecordAdditions_h
#define TKTLVRecordAdditions_h
#import "YKFTLVRecord.h"

@interface YKFTLVRecord(Additions)

+ (NSData * _Nullable)valueFromData:(NSData * _Nonnull)data withTag:(UInt64)tag error:(NSError *_Nullable* _Nullable)error;

@end

#endif /* TKTLVRecordAdditions_h */
