//
//  YKFChalRespRequest+Private.h
//  YubiKit
//
//  Created by Irina Makhalova on 12/26/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#ifndef YKFChalRespRequest_Private_h
#define YKFChalRespRequest_Private_h

#import <Foundation/Foundation.h>
#import "YKFChalRespRequest.h"
#import "YKFAPDU.h"
NS_ASSUME_NONNULL_BEGIN

@interface YKFChalRespRequest()

@property (nonatomic) YKFAPDU *apdu;

@end

NS_ASSUME_NONNULL_END

#endif /* YKFChalRespRequest_Private_h */
