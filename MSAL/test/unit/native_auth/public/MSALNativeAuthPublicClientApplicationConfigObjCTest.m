//
//  MSALNativeAuthPublicClientApplicationConfigObjCTest.m
//  MSAL
//
//  Created by daniloraspa on 24/06/2025.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MSAL/MSAL.h>

@interface MSALNativeAuthPublicClientApplicationConfigObjCTest : XCTestCase

@end

@implementation MSALNativeAuthPublicClientApplicationConfigObjCTest

- (void)test_capabilitiesVisibility {
    NSError *error = nil;
    MSALNativeAuthPublicClientApplicationConfig *config = [[MSALNativeAuthPublicClientApplicationConfig alloc] initWithClientId:@"clientId" tenantSubdomain:@"tenantSubdomain" challengeTypes:MSALNativeAuthChallengeTypeOOB error:&error];
    config.capabilities = MSALNativeAuthCapabilityMFARequired;
}

@end
