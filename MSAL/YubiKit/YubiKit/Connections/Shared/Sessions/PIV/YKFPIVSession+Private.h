//
//  YKFPIVSession+Private.h
//  YubiKit
//
//  Created by Jens Utbult on 2021-02-11.
//  Copyright © 2021 Yubico. All rights reserved.
//

#ifndef YKFPIVSession_Private_h
#define YKFPIVSession_Private_h

#import <Foundation/Foundation.h>
#import "YKFSessionProtocol+Private.h"
#import "YKFPIVSession.h"

@protocol YKFConnectionControllerProtocol;

@interface YKFPIVSession()<YKFSessionProtocol>

typedef void (^YKFPIVSessionCompletion)(YKFPIVSession *_Nullable, NSError* _Nullable);
+ (void)sessionWithConnectionController:(nonnull id<YKFConnectionControllerProtocol>)connectionController
                             completion:(YKFPIVSessionCompletion _Nonnull)completion;

@end

#endif
