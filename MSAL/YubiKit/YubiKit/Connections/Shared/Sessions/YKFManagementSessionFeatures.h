//
//  YKFManagementSessionFeatures.h
//  YubiKit
//
//  Created by Jens Utbult on 2021-04-28.
//  Copyright © 2021 Yubico. All rights reserved.
//

#ifndef YKFManagementSessionFeatures_h
#define YKFManagementSessionFeatures_h

@class YKFFeature;

@interface YKFManagementSessionFeatures : NSObject
@property (nonatomic, readonly) YKFFeature * _Nonnull deviceInfo;
@property (nonatomic, readonly) YKFFeature * _Nonnull deviceConfig;
@end

#endif /* YKFManagementSessionFeatures_h */
