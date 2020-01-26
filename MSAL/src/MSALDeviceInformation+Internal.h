//
//  MSALDeviceInformation_Internal.h
//  MSAL
//
//  Created by Olga Dalton on 1/25/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSALDeviceInformation.h"

@class MSIDDeviceInfo;

NS_ASSUME_NONNULL_BEGIN

@interface MSALDeviceInformation()

- (instancetype)initWithMSIDDeviceInfo:(MSIDDeviceInfo *)deviceInfo;

@end

NS_ASSUME_NONNULL_END
