//
//  MSALTenantDiscoveryResponse.h
//  MSAL
//
//  Created by Jason Kim on 2/15/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSALJsonObject.h"

@interface MSALTenantDiscoveryResponse : MSALJsonObject

@property (readonly) NSString *authorization_endpoint;
@property (readonly) NSString *token_endpoint;
@property (readonly) NSString *issuer;

@end
