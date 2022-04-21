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

typedef NS_ENUM(NSUInteger, YKFFIDO2ErrorCode) {
    
    /*! Indicates successful response.
     */
    YKFFIDO2ErrorCodeSUCCESS = 0x00,
    
    /*! The command is not a valid CTAP command.
     */
    YKFFIDO2ErrorCodeINVALID_COMMAND = 0x01,
    
    /*! The command included an invalid parameter.
     */
    YKFFIDO2ErrorCodeINVALID_PARAMETER = 0x02,
    
    /*! Invalid message or item length.
     */
    YKFFIDO2ErrorCodeINVALID_LENGTH = 0x03,
    
    /*! Invalid message sequencing.
     */
    YKFFIDO2ErrorCodeINVALID_SEQ = 0x04,
    
    /*! Message timed out.
     */
    YKFFIDO2ErrorCodeTIMEOUT = 0x05,
    
    /*! Channel busy.
     */
    YKFFIDO2ErrorCodeCHANNEL_BUSY = 0x06,
    
    /*! Command requires channel lock.
     */
    YKFFIDO2ErrorCodeLOCK_REQUIRED = 0x0A,
    
    /*! Command not allowed on this cid.
     */
    YKFFIDO2ErrorCodeINVALID_CHANNEL = 0x0B,
    
    /*! Other unspecified error.
     */
    YKFFIDO2ErrorCodeOTHER = 0x7F,
    
    /*! Invalid/unexpected CBOR error.
     */
    YKFFIDO2ErrorCodeCBOR_UNEXPECTED_TYPE = 0x11,
    
    /*! Error when parsing CBOR.
     */
    YKFFIDO2ErrorCodeINVALID_CBOR = 0x12,
    
    /*! Missing non-optional parameter.
     */
    YKFFIDO2ErrorCodeMISSING_PARAMETER = 0x14,
    
    /*! Limit for number of items exceeded.
     */
    YKFFIDO2ErrorCodeLIMIT_EXCEEDED = 0x15,
    
    /*! Unsupported extension.
     */
    YKFFIDO2ErrorCodeUNSUPPORTED_EXTENSION = 0x16,
    
    /*! Valid credential found in the exclude list.
     */
    YKFFIDO2ErrorCodeCREDENTIAL_EXCLUDED = 0x19,
    
    /*! Lengthy operation is in progress.
     */
    YKFFIDO2ErrorCodePROCESSING = 0x21,
    
    /*! Credential not valid for the authenticator.
     */
    YKFFIDO2ErrorCodeINVALID_CREDENTIAL = 0x22,
    
    /*! Authentication is waiting for user interaction.
     */
    YKFFIDO2ErrorCodeUSER_ACTION_PENDING = 0x23,
    
    /*! Processing, lengthy operation is in progress.
     */
    YKFFIDO2ErrorCodeOPERATION_PENDING = 0x24,
    
    /*! No request is pending.
     */
    YKFFIDO2ErrorCodeNO_OPERATIONS = 0x25,
    
    /*! Authenticator does not support requested algorithm.
     */
    YKFFIDO2ErrorCodeUNSUPPORTED_ALGORITHM = 0x26,
    
    /*! Not authorized for requested operation.
     */
    YKFFIDO2ErrorCodeOPERATION_DENIED = 0x27,
    
    /*! Internal key storage is full.
     */
    YKFFIDO2ErrorCodeKEY_STORE_FULL = 0x28,
    
    /*! Authenticator cannot cancel as it is not busy.
     */
    YKFFIDO2ErrorCodeNOT_BUSY = 0x29,
    
    /*! No outstanding operations.
     */
    YKFFIDO2ErrorCodeNO_OPERATION_PENDING = 0x2A,
    
    /*! Unsupported option.
     */
    YKFFIDO2ErrorCodeUNSUPPORTED_OPTION = 0x2B,
    
    /*! Not a valid option for current operation.
     */
    YKFFIDO2ErrorCodeINVALID_OPTION = 0x2C,
    
    /*! Pending keep alive was cancelled.
     */
    YKFFIDO2ErrorCodeKEEPALIVE_CANCEL = 0x2D,
    
    /*! No valid credentials provided.
     */
    YKFFIDO2ErrorCodeNO_CREDENTIALS = 0x2E,
    
    /*! Timeout waiting for user interaction.
     */
    YKFFIDO2ErrorCodeUSER_ACTION_TIMEOUT = 0x2F,
    
    /*! Continuation command, such as, authenticatorGetNextAssertion not allowed.
     */
    YKFFIDO2ErrorCodeNOT_ALLOWED = 0x30,
    
    /*! PIN Invalid.
     */
    YKFFIDO2ErrorCodePIN_INVALID = 0x31,
    
    /*! PIN Blocked.
     */
    YKFFIDO2ErrorCodePIN_BLOCKED = 0x32,
    
    /*! PIN authentication,pinAuth, verification failed.
     */
    YKFFIDO2ErrorCodePIN_AUTH_INVALID = 0x33,
    
    /*! PIN authentication,pinAuth, blocked. Requires power recycle to reset.
     */
    YKFFIDO2ErrorCodePIN_AUTH_BLOCKED = 0x34,
    
    /*! No PIN has been set.
     */
    YKFFIDO2ErrorCodePIN_NOT_SET = 0x35,
    
    /*! PIN is required for the selected operation.
     */
    YKFFIDO2ErrorCodePIN_REQUIRED = 0x36,
    
    /*! PIN policy violation. Currently only enforces minimum length.
     */
    YKFFIDO2ErrorCodePIN_POLICY_VIOLATION = 0x37,
    
    /*! pinToken expired on authenticator.
     */
    YKFFIDO2ErrorCodePIN_TOKEN_EXPIRED = 0x38,
    
    /*! Authenticator cannot handle this request due to memory constraints.
     */
    YKFFIDO2ErrorCodeREQUEST_TOO_LARGE = 0x39,
    
    /*! The current operation has timed out.
     */
    YKFFIDO2ErrorCodeACTION_TIMEOUT = 0x3A,
    
    /*! User presence is required for the requested operation.
     */
    YKFFIDO2ErrorCodeUP_REQUIRED = 0x3B,
    
    /*! CTAP 2 spec last error.
     */
    YKFFIDO2ErrorCodeSPEC_LAST = 0xDF,
    
    /*! Extension specific error.
     */
    YKFFIDO2ErrorCodeEXTENSION_FIRST = 0xE0,
    
    /*! Extension specific error.
     */
    YKFFIDO2ErrorCodeEXTENSION_LAST = 0xEF,
    
    /*! Vendor specific error.
     */
    YKFFIDO2ErrorCodeVENDOR_FIRST = 0xF0,
    
    /*! Vendor specific error.
     */
    YKFFIDO2ErrorCodeVENDOR_LAST = 0xFF,
};

NS_ASSUME_NONNULL_BEGIN

/*!
 @class
    YKFFIDO2Error
 @abstract
    Error type returned by the YKFFIDO2Service.
 */
@interface YKFFIDO2Error: YKFSessionError
@end

NS_ASSUME_NONNULL_END
