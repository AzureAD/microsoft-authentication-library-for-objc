//
//  MSALAadAuthority.m
//  MSAL
//
//  Created by Jason Kim on 2/14/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "MSALAadAuthority.h"

@implementation MSALAadAuthority

- (void)openIdConfigurationEndpointForHost:(NSString *)host
                                    tenant:(NSString *)tenant
                         userPrincipalName:(NSString *)userPrincipalName
                          compltionHandler:(void (^)(NSString *, NSError *))completionHandler
{
    (void)host;
    (void)tenant;
    (void)userPrincipalName;
    (void)completionHandler;
}

@end
