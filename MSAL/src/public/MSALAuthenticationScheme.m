//
//  MSALAuthenticationScheme.m
//  MSAL
//
//  Created by Rohit Narula on 5/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSALAuthenticationScheme.h"
#import "MSALAuthenticationSchemeBearer.h"
#import "MSALAuthenticationSchemePop.h"

@implementation MSALAuthenticationScheme

- (instancetype)initWithScheme:(MSALAuthScheme)scheme
{
    if( [self class] == [MSALAuthenticationScheme class])
    {
        NSString *message = [NSString stringWithFormat:@"You cannot initialize this class directly, Use a subclass instead : %@ or %@", [MSALAuthenticationSchemeBearer class], [MSALAuthenticationSchemePop class]];
        NSAssert(false, message);
        return nil;
    }
    else
    {
        _scheme = scheme;
        return [super init];
    }
}

@end
