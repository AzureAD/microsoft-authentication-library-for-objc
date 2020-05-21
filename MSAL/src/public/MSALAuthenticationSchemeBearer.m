//
//  MSALBearerAuthenticationScheme.m
//  MSAL
//
//  Created by Rohit Narula on 5/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSALAuthenticationSchemeBearer.h"
#import "MSIDAuthenticationScheme.h"

@implementation MSALAuthenticationSchemeBearer

- (instancetype)init
{
    self = [super initWithScheme:MSALAuthSchemeBearer];
    return self;
}

- (MSIDAuthenticationScheme *)msidAuthScheme
{
    return [[MSIDAuthenticationScheme alloc] init];
}

@end
