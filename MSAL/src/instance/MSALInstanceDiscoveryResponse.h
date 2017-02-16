//
//  MSALInstanceDiscoveryResponse.h
//  MSAL
//
//  Created by Jason Kim on 2/15/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSALJsonObject.h"

@interface MSALInstanceDiscoveryResponse : MSALJsonObject

@property(readonly) NSString *tenant_discovery_endpoint;

@end
