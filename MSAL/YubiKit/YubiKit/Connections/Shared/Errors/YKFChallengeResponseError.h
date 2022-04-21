//
//  YKFChallengeResponseError.h
//  YubiKit
//
//  Created by Irina Makhalova on 12/30/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YKFSessionError.h"

typedef NS_ENUM(NSUInteger, YKFChallengeResponseErrorCode) {
    
    /*! The host application does not have any active connection with YubiKey
     */
    YKFChallengeResponseErrorCodeNoConnection = YKFSessionErrorNoConnection,
    
    /*! Key does not have programmed secret on slot
     */
    YKFChallengeResponseErrorCodeEmptyResponse = 0x000201,
};

NS_ASSUME_NONNULL_BEGIN

/*!
@class
   YKFChallengeResponseError
@abstract
   Error type returned by the YKFChallengeResponseService.
*/
@interface YKFChallengeResponseError : YKFSessionError

@end

NS_ASSUME_NONNULL_END
