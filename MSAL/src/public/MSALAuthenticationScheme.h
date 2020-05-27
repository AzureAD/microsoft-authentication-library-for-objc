//
//  MSALAuthenticationScheme.h
//  MSAL
//
//  Created by Rohit Narula on 5/26/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSALDefinitions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSALAuthenticationScheme : NSObject

@property (nonatomic) MSALAuthScheme scheme;

- (instancetype)initWithScheme:(MSALAuthScheme)scheme;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
