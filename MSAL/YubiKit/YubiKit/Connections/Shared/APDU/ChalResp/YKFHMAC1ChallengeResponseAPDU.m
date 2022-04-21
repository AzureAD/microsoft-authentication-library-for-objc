//
//  YKFYubiKeySendChallengeAPDU.m
//  YubiKit
//
//  Created by Irina Makhalova on 12/20/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import "YKFHMAC1ChallengeResponseAPDU.h"
#import "YKFChalRespSendRequest.h"
#import "YKFAssert.h"
#import "YKFAPDUCommandInstruction.h"

@implementation YKFHMAC1ChallengeResponseAPDU

- (instancetype)initWithRequest:(YKFChalRespSendRequest *)request {
    YKFAssertAbortInit(request);
    
    UInt8 slot = request.slot == YKFSlotOne ? 0x30 : 0x38;
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionChalRespSend p1:slot p2:0 data:request.challenge type:YKFAPDUTypeShort];
}

@end
