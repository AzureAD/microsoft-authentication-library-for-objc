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

#import "YKFFIDO2Error.h"
#import "YKFSessionError+Private.h"

#pragma mark - Error Descriptions

static NSString* const YKFFIDO2ErrorSUCCESS = @"Successful response";
static NSString* const YKFFIDO2ErrorINVALID_COMMAND = @"The command is not a valid CTAP command.";
static NSString* const YKFFIDO2ErrorINVALID_PARAMETER = @"The command included an invalid parameter.";
static NSString* const YKFFIDO2ErrorINVALID_LENGTH = @"Invalid message or item length.";
static NSString* const YKFFIDO2ErrorINVALID_SEQ = @"Invalid message sequencing.";
static NSString* const YKFFIDO2ErrorTIMEOUT = @"Message timed out.";
static NSString* const YKFFIDO2ErrorCHANNEL_BUSY = @"Channel busy.";
static NSString* const YKFFIDO2ErrorLOCK_REQUIRED = @"Command requires channel lock.";
static NSString* const YKFFIDO2ErrorINVALID_CHANNEL = @"Command not allowed on this cid.";
static NSString* const YKFFIDO2ErrorOTHER = @"Other unspecified error.";
static NSString* const YKFFIDO2ErrorCBOR_UNEXPECTED_TYPE = @"Invalid/unexpected CBOR error.";
static NSString* const YKFFIDO2ErrorINVALID_CBOR = @"Error when parsing CBOR.";
static NSString* const YKFFIDO2ErrorMISSING_PARAMETER = @"Missing non-optional parameter.";
static NSString* const YKFFIDO2ErrorLIMIT_EXCEEDED = @"Limit for number of items exceeded.";
static NSString* const YKFFIDO2ErrorUNSUPPORTED_EXTENSION = @"Unsupported extension.";
static NSString* const YKFFIDO2ErrorCREDENTIAL_EXCLUDED = @"Valid credential found in the exclude list.";
static NSString* const YKFFIDO2ErrorPROCESSING = @"Lengthy operation is in progress.";
static NSString* const YKFFIDO2ErrorINVALID_CREDENTIAL = @"Credential not valid for the authenticator.";
static NSString* const YKFFIDO2ErrorUSER_ACTION_PENDING = @"Authentication is waiting for user interaction.";
static NSString* const YKFFIDO2ErrorOPERATION_PENDING = @"Processing, lengthy operation is in progress.";
static NSString* const YKFFIDO2ErrorNO_OPERATIONS = @"No request is pending.";
static NSString* const YKFFIDO2ErrorUNSUPPORTED_ALGORITHM = @"Authenticator does not support requested algorithm.";
static NSString* const YKFFIDO2ErrorOPERATION_DENIED = @"Not authorized for requested operation.";
static NSString* const YKFFIDO2ErrorKEY_STORE_FULL = @"Internal key storage is full.";
static NSString* const YKFFIDO2ErrorNOT_BUSY = @"Authenticator cannot cancel as it is not busy.";
static NSString* const YKFFIDO2ErrorNO_OPERATION_PENDING = @"No outstanding operations.";
static NSString* const YKFFIDO2ErrorUNSUPPORTED_OPTION = @"Unsupported option.";
static NSString* const YKFFIDO2ErrorINVALID_OPTION = @"Not a valid option for current operation.";
static NSString* const YKFFIDO2ErrorKEEPALIVE_CANCEL = @"Pending keep alive was cancelled.";
static NSString* const YKFFIDO2ErrorNO_CREDENTIALS = @"No valid credentials provided.";
static NSString* const YKFFIDO2ErrorUSER_ACTION_TIMEOUT = @"Timeout waiting for user interaction.";
static NSString* const YKFFIDO2ErrorNOT_ALLOWED = @"Continuation command, such as, authenticatorGetNextAssertion not allowed.";
static NSString* const YKFFIDO2ErrorPIN_INVALID = @"PIN Invalid.";
static NSString* const YKFFIDO2ErrorPIN_BLOCKED = @"PIN Blocked.";
static NSString* const YKFFIDO2ErrorPIN_AUTH_INVALID = @"PIN authentication,pinAuth, verification failed.";
static NSString* const YKFFIDO2ErrorPIN_AUTH_BLOCKED = @"PIN authentication,pinAuth, blocked. Requires power recycle to reset.";
static NSString* const YKFFIDO2ErrorPIN_NOT_SET = @"No PIN has been set.";
static NSString* const YKFFIDO2ErrorPIN_REQUIRED = @"PIN is required for the selected operation.";
static NSString* const YKFFIDO2ErrorPIN_POLICY_VIOLATION = @"PIN policy violation. Currently only enforces minimum length.";
static NSString* const YKFFIDO2ErrorPIN_TOKEN_EXPIRED = @"pinToken expired on authenticator.";
static NSString* const YKFFIDO2ErrorREQUEST_TOO_LARGE = @"Authenticator cannot handle this request due to memory constraints.";
static NSString* const YKFFIDO2ErrorACTION_TIMEOUT = @"The current operation has timed out.";
static NSString* const YKFFIDO2ErrorUP_REQUIRED = @"User presence is required for the requested operation.";

#pragma mark - YKFFIDO2Error

@implementation YKFFIDO2Error

static NSDictionary *errorMap = nil;

+ (YKFSessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFFIDO2Error buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFSessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFFIDO2ErrorCodeSUCCESS): YKFFIDO2ErrorSUCCESS,
      @(YKFFIDO2ErrorCodeINVALID_COMMAND): YKFFIDO2ErrorINVALID_COMMAND,
      @(YKFFIDO2ErrorCodeINVALID_PARAMETER): YKFFIDO2ErrorINVALID_PARAMETER,
      @(YKFFIDO2ErrorCodeINVALID_LENGTH): YKFFIDO2ErrorINVALID_LENGTH,
      @(YKFFIDO2ErrorCodeINVALID_SEQ): YKFFIDO2ErrorINVALID_SEQ,
      @(YKFFIDO2ErrorCodeTIMEOUT): YKFFIDO2ErrorTIMEOUT,
      @(YKFFIDO2ErrorCodeCHANNEL_BUSY): YKFFIDO2ErrorCHANNEL_BUSY,
      @(YKFFIDO2ErrorCodeLOCK_REQUIRED): YKFFIDO2ErrorLOCK_REQUIRED,
      @(YKFFIDO2ErrorCodeINVALID_CHANNEL): YKFFIDO2ErrorINVALID_CHANNEL,
      @(YKFFIDO2ErrorCodeOTHER): YKFFIDO2ErrorOTHER,
      @(YKFFIDO2ErrorCodeCBOR_UNEXPECTED_TYPE): YKFFIDO2ErrorCBOR_UNEXPECTED_TYPE,
      @(YKFFIDO2ErrorCodeINVALID_CBOR): YKFFIDO2ErrorINVALID_CBOR,
      @(YKFFIDO2ErrorCodeMISSING_PARAMETER): YKFFIDO2ErrorMISSING_PARAMETER,
      @(YKFFIDO2ErrorCodeLIMIT_EXCEEDED): YKFFIDO2ErrorLIMIT_EXCEEDED,
      @(YKFFIDO2ErrorCodeUNSUPPORTED_EXTENSION): YKFFIDO2ErrorUNSUPPORTED_EXTENSION,
      @(YKFFIDO2ErrorCodeCREDENTIAL_EXCLUDED): YKFFIDO2ErrorCREDENTIAL_EXCLUDED,
      @(YKFFIDO2ErrorCodePROCESSING): YKFFIDO2ErrorPROCESSING,
      @(YKFFIDO2ErrorCodeINVALID_CREDENTIAL): YKFFIDO2ErrorINVALID_CREDENTIAL,
      @(YKFFIDO2ErrorCodeUSER_ACTION_PENDING): YKFFIDO2ErrorUSER_ACTION_PENDING,
      @(YKFFIDO2ErrorCodeOPERATION_PENDING): YKFFIDO2ErrorOPERATION_PENDING,
      @(YKFFIDO2ErrorCodeNO_OPERATIONS): YKFFIDO2ErrorNO_OPERATIONS,
      @(YKFFIDO2ErrorCodeUNSUPPORTED_ALGORITHM): YKFFIDO2ErrorUNSUPPORTED_ALGORITHM,
      @(YKFFIDO2ErrorCodeOPERATION_DENIED): YKFFIDO2ErrorOPERATION_DENIED,
      @(YKFFIDO2ErrorCodeKEY_STORE_FULL): YKFFIDO2ErrorKEY_STORE_FULL,
      @(YKFFIDO2ErrorCodeNOT_BUSY): YKFFIDO2ErrorNOT_BUSY,
      @(YKFFIDO2ErrorCodeNO_OPERATION_PENDING): YKFFIDO2ErrorNO_OPERATION_PENDING,
      @(YKFFIDO2ErrorCodeUNSUPPORTED_OPTION): YKFFIDO2ErrorUNSUPPORTED_OPTION,
      @(YKFFIDO2ErrorCodeINVALID_OPTION): YKFFIDO2ErrorINVALID_OPTION,
      @(YKFFIDO2ErrorCodeKEEPALIVE_CANCEL): YKFFIDO2ErrorKEEPALIVE_CANCEL,
      @(YKFFIDO2ErrorCodeNO_CREDENTIALS): YKFFIDO2ErrorNO_CREDENTIALS,
      @(YKFFIDO2ErrorCodeUSER_ACTION_TIMEOUT): YKFFIDO2ErrorUSER_ACTION_TIMEOUT,
      @(YKFFIDO2ErrorCodeNOT_ALLOWED): YKFFIDO2ErrorNOT_ALLOWED,
      @(YKFFIDO2ErrorCodePIN_INVALID): YKFFIDO2ErrorPIN_INVALID,
      @(YKFFIDO2ErrorCodePIN_BLOCKED): YKFFIDO2ErrorPIN_BLOCKED,
      @(YKFFIDO2ErrorCodePIN_AUTH_INVALID): YKFFIDO2ErrorPIN_AUTH_INVALID,
      @(YKFFIDO2ErrorCodePIN_AUTH_BLOCKED): YKFFIDO2ErrorPIN_AUTH_BLOCKED,
      @(YKFFIDO2ErrorCodePIN_NOT_SET): YKFFIDO2ErrorPIN_NOT_SET,
      @(YKFFIDO2ErrorCodePIN_REQUIRED): YKFFIDO2ErrorPIN_REQUIRED,
      @(YKFFIDO2ErrorCodePIN_POLICY_VIOLATION): YKFFIDO2ErrorPIN_POLICY_VIOLATION,
      @(YKFFIDO2ErrorCodePIN_TOKEN_EXPIRED): YKFFIDO2ErrorPIN_TOKEN_EXPIRED,
      @(YKFFIDO2ErrorCodeREQUEST_TOO_LARGE): YKFFIDO2ErrorREQUEST_TOO_LARGE,
      @(YKFFIDO2ErrorCodeACTION_TIMEOUT): YKFFIDO2ErrorACTION_TIMEOUT,
      @(YKFFIDO2ErrorCodeUP_REQUIRED): YKFFIDO2ErrorUP_REQUIRED
      };
}

@end
