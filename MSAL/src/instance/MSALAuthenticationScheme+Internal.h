//
//  MSALAuthenticationScheme+Internal.h
//  MSAL
//
//  Created by Rohit Narula on 5/21/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSALAuthenticationScheme.h"
#import "MSIDAuthenticationScheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSALAuthenticationScheme ()

@property (nonatomic, readonly) MSIDAuthenticationScheme *msidAuthScheme;

@end

NS_ASSUME_NONNULL_END
