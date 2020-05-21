//
//  MSALPopAuthenticationScheme.m
//  MSAL
//
//  Created by Rohit Narula on 5/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSALAuthenticationSchemePop.h"
#import "MSIDAuthenticationScheme.h"
#import "MSALHttpMethod.h"

@implementation MSALAuthenticationSchemePop

- (instancetype)initWithHttpMethod:(MSALHttpMethod)httpMethod requestUrl:(NSURL *)requestUrl
{
    self = [super initWithScheme:MSALAuthSchemePop];
    if (self)
    {
        _httpMethod = httpMethod;
        _requestUrl = requestUrl;
        _nonce = [[NSUUID UUID] UUIDString];
    }
    
    return self;
}

- (MSIDAuthenticationScheme *)msidAuthScheme
{
    return [[MSIDAuthenticationScheme alloc] initWithHttpMethod:MSIDHttpMethodForHttpMethod(_httpMethod) requestUrl:self.requestUrl nonce:self.nonce];
}


@end
