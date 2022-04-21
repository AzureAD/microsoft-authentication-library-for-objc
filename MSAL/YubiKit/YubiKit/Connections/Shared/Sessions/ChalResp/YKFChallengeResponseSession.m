//
//  YKFChallengeResponseService.m
//  YubiKit
//
//  Created by Irina Makhalova on 12/18/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import "YKFChallengeResponseSession.h"
#import "YubiKitManager.h"
#import "YKFSession+Private.h"
#import "YKFChalRespSendRequest.h"
#import "YKFChalRespRequest+Private.h"
#import "YKFChallengeResponseError.h"
#import "YKFChallengeResponseSession+Private.h"
#import "YKFSmartCardInterface.h"
#import "YKFChallengeResponseError.h"
#import "YKFSessionError+Private.h"
#import "YKFSelectApplicationAPDU.h"

@implementation YKFChallengeResponseSession

+ (void)sessionWithConnectionController:(nonnull id<YKFConnectionControllerProtocol>)connectionController
                               completion:(YKFChallengeResponseSessionCompletion _Nonnull)completion {
    
    YKFChallengeResponseSession *session = [YKFChallengeResponseSession new];
    session.smartCardInterface = [[YKFSmartCardInterface alloc] initWithConnectionController:connectionController];
    
    YKFSelectApplicationAPDU *apdu = [[YKFSelectApplicationAPDU alloc] initWithApplicationName:YKFSelectApplicationAPDUNameChalResp];
    [session.smartCardInterface selectApplication:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else {
            completion(session, nil);
        }
    }];
}

- (void)sendChallenge:(nonnull NSData *)challenge slot:(YKFSlot)slot completion:(nonnull YKFChallengeResponseSessionResponseBlock)completion {
    YKFChalRespSendRequest *request = [[YKFChalRespSendRequest alloc] initWithChallenge:challenge slot: slot];
    [self.smartCardInterface executeCommand:request.apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else if (data.length == 0) {
            completion(nil, [YKFChallengeResponseError errorWithCode:YKFChallengeResponseErrorCodeEmptyResponse]);
        } else {
            completion(data, nil);
        }
    }];
}

- (void)clearSessionState {
    ;
}

@end
