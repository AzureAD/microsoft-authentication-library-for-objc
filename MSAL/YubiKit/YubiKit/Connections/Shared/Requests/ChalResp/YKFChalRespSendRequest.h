//
//  YKFChalRespSendRequest.h
//  YubiKit
//
//  Created by Irina Makhalova on 12/26/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YKFSlot.h"
#import "YKFChalRespRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface YKFChalRespSendRequest : YKFChalRespRequest

@property (nonatomic, readonly, nonnull) NSData *challenge;
@property (nonatomic, readonly) YKFSlot slot;


- (nullable instancetype)initWithChallenge:(nonnull NSData*)challenge slot:(YKFSlot) slot NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithChallenge: slot:].
 */
- (nonnull instancetype)init NS_UNAVAILABLE;


@end

NS_ASSUME_NONNULL_END
