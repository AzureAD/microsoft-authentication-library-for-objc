//
//  YKFChallengeResponseService.h
//  YubiKit
//
//  Created by Irina Makhalova on 12/18/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "YKFSession.h"
#import "YKFSlot.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Challenge-Response session Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Response block for [sendChallenge:slot:completion:] which provides the result for the execution
    of the request.
 
 @param response
    The response of the request when it was successful and contains data. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful
    this parameter is nil.
 */
typedef void (^YKFChallengeResponseSessionResponseBlock)
    (NSData* _Nullable response, NSError* _Nullable error);

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name HMAC-SHA1 Challenge Response Service Protocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
@abstract
   Defines the interface for YKFChallengeResponseSession.
*/
@interface YKFChallengeResponseSession: YKFSession

/*!
@method sendChallenge:slot:completion:

@abstract
    Sends a challenge to the key. The request is performed asynchronously
    on a background execution queue.

@param challenge
    The challenge that needs to be sent to YubiKey

@param slot
    The slot that configured with challenge-response secret (first or second)

@param completion
   The response block which is executed after the request was processed by the key. The completion block
   will be executed on a background thread.

@note:
   This method is thread safe and can be invoked from any thread (main or a background thread).
*/
- (void)sendChallenge:(NSData *)challenge slot:(YKFSlot) slot completion:(YKFChallengeResponseSessionResponseBlock)completion;

- (nonnull instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
