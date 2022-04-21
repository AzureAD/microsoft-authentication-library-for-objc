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

#import "YKFSessionError.h"

typedef NS_ENUM(NSUInteger, YKFOATHErrorCode) {
    
    /*! The host application tried to perform an OATH put credential operation with a credential which has a name longer then the
     maximum allowed length by the key.
     */
    YKFOATHErrorCodeNameTooLong = 0x000100,
    
    /*! The host application tried to perform an OATH put credential operation with a credential which has a secret longer then the
     maximum allowed length of the SHA block size. The size of the secret should be less or equal to the size of the hash algorithm.
     */
    YKFOATHErrorCodeSecretTooLong = 0x000101,
    
    /*! The key did not return correct data to a calculate request.
     */
    YKFOATHErrorCodeBadCalculationResponse = 0x000102,
    
    /*! The key did not return correct data for a list request.
     */
    YKFOATHErrorCodeBadListResponse = 0x000103,
    
    /*! The key did not return correct data when selecting the key OATH application.
     */
    YKFOATHErrorCodeBadApplicationSelectionResponse = 0x000104,
    
    /*! The OATH application requires a validate call to unlock the application, when a password/code is set.
     */
    YKFOATHErrorCodeAuthenticationRequired = 0x000105,
    
    /*! The key did not return correct data when validating a code set on the OATH application.
     */
    YKFOATHErrorCodeBadValidationResponse = 0x000106,
    
    /*! The key did not return correct data when calculating all credentials.
     */
    YKFOATHErrorCodeBadCalculateAllResponse = 0x000107,
    
    /*! The key did time out, waiting for the user to touch the key when calculating a credential which requires touch.
     */
    YKFOATHErrorCodeTouchTimeout = 0x000108,
    
    /*! Wrong password used for authentication.
     */
    YKFOATHErrorCodeWrongPassword = 0x000109,

    /*! Object was not found in list of credentials
     */
    YKFOATHErrorCodeNoSuchObject = 0x00010A

};


NS_ASSUME_NONNULL_BEGIN

/*!
 @class
    YKFOATHError
 @abstract
    Error type returned by the YKFOATHService.
 */
@interface YKFOATHError: YKFSessionError
@end

NS_ASSUME_NONNULL_END
