//
//  MSALSchemeProtocol.h
//  MSAL
//
//  Created by Rohit Narula on 5/27/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDAuthenticationSchemeProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MSALAuthenticationSchemeProtocol <NSObject>

@property (nonatomic) MSALAuthScheme scheme;
@property (nonatomic, readonly) id<MSIDAuthenticationSchemeProtocol> msidAuthScheme;

@end

NS_ASSUME_NONNULL_END
