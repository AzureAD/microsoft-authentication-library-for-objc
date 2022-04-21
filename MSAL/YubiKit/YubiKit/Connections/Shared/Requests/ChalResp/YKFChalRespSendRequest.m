//
//  YKFChalRespSendRequest.m
//  YubiKit
//
//  Created by Irina Makhalova on 12/26/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import "YKFChalRespSendRequest.h"
#import "YKFChalRespRequest+Private.h"
#import "YKFHMAC1ChallengeResponseAPDU.h"
#import "YKFAssert.h"

@interface YKFChalRespSendRequest()

@property (nonatomic, readwrite) NSData *challenge;
@property (nonatomic, readwrite) YKFSlot slot;
@end

@implementation YKFChalRespSendRequest

- (nullable instancetype)initWithChallenge:(nonnull NSData*)challenge slot:(YKFSlot) slot {
    YKFAssertAbortInit(challenge);
    
    self = [super init];
    if (self) {
        self.challenge = challenge;
        self.slot = slot;
        self.apdu = [[YKFHMAC1ChallengeResponseAPDU alloc] initWithRequest:self];
    }
    return self;
}

@end
