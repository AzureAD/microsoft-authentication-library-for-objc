// Copyright 2018-2019 Yubico AB
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
#import <CommonCrypto/CommonCrypto.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData(NSData_Marshalling)

- (NSUInteger)ykf_getBigEndianIntegerInRange:(NSRange)range;

@end

@interface NSData (NSDATA_OATHAdditions)

- (nullable NSData *)ykf_deriveOATHKeyWithSalt:(NSData *)salt;
- (nullable NSData *)ykf_oathHMACWithKey:(NSData *)key;
- (nullable NSString *)ykf_parseOATHOTPFromIndex:(NSUInteger)index digits:(UInt8)digits;

@end

@interface NSData (NSDATA_FIDO2Additions)

- (nullable NSData *)ykf_fido2HMACWithKey:(NSData *)key;

- (nullable NSData *)ykf_aes256EncryptedDataWithKey:(NSData *)key;
- (nullable NSData *)ykf_aes256DecryptedDataWithKey:(NSData *)key;
- (nullable NSData *)ykf_aes256Operation:(CCOperation)operation withKey:(NSData *)key;

- (nullable NSData *)ykf_fido2PaddedPinData;

@end

@interface NSData (NSDATA_PIVAdditions)

- (nullable NSData *)ykf_encryptDataWithAlgorithm:(CCAlgorithm)algorithm key:(NSData *)key;
- (nullable NSData *)ykf_decryptedDataWithAlgorithm:(CCAlgorithm)algorithm key:(NSData *)key;
- (nullable NSData *)ykf_cryptOperation:(CCOperation)operation algorithm:(CCAlgorithm)algorithm key:(NSData *)key;

+ (nullable NSData *)ykf_randomDataOfSize:(size_t)sizeInBytes;

- (NSData *)ykf_toLength:(int)length;

@end

@interface NSData(NSDATA_SizeCheckAdditions)

- (BOOL)ykf_containsIndex:(NSUInteger) index;
- (BOOL)ykf_containsRange:(NSRange) range;

@end

@interface NSData(NSData_Conversion)
/*!
 @method ykf_hexadecimalString:
 
 @return
    A string from data object which represents each byte as hex symbols.
 */
- (NSString *)ykf_hexadecimalString;

@end


@interface NSData (NSData_IntConversion)

/*!
@method ykf_integerValue:

@return
   An integer value from data object.
*/
- (NSUInteger)ykf_integerValue;

@end

NS_ASSUME_NONNULL_END
