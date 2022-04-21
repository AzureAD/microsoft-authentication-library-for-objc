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

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFU2FSignResponse
 
 @abstract
    Data model which contains the result of a sign request sent to the key.
 @discussion
    The application should not process the content of this response, like parsing it, unless there is a
    good reason for it. The result is usually sent back to the authentication server for validation.
 */
@interface YKFU2FSignResponse : NSObject

/*!
 @property keyHandle
 
 @abstract
    The keyHandle passed to the key when the sign operation was requested.
 @discussion
    Format as defined by the FIDO Alliance specifications
    ---
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#authentication-messages
 */
@property (nonatomic, readonly) NSString *keyHandle;

/*!
 @property clientData
 
 @abstract
    The clientData data structure as defined by the U2F standard.
 @discussion
    The full specification of the client data format as defined by the FIDO Alliance specifications
    ---
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#client-data
 */
@property (nonatomic, readonly) NSString *clientData;

/*!
 @property signature
 
 @abstract
    The signature produced by the key after the signing operation.
 @discussion
    The details for the signature format
    ---
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#authentication-response-message-success
 */
@property (nonatomic, readonly) NSData *signature;

/*
 Not available: this type of response should be created only by the library.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
