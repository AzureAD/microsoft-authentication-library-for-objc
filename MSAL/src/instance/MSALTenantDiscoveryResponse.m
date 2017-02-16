//
//  MSALTenantDiscoveryResponse.m
//  MSAL
//
//  Created by Jason Kim on 2/15/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "MSALTenantDiscoveryResponse.h"

@implementation MSALTenantDiscoveryResponse

MSAL_JSON_ACCESSOR(@"issuer", issuer)
MSAL_JSON_ACCESSOR(@"authorization_endpoint", authorization_endpoint)
MSAL_JSON_ACCESSOR(@"token_endpoint", token_endpoint)

@end
