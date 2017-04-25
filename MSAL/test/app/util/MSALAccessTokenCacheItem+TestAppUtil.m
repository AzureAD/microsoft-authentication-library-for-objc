//
//  MSALAccessTokenCacheItem+TestAppUtil.m
//  MSAL
//
//  Created by Olga Dalton on 4/24/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "MSALAccessTokenCacheItem+TestAppUtil.h"

@implementation MSALAccessTokenCacheItem (TestAppUtil)

MSAL_JSON_RW(@"expires_on", expiresOnString, setExpiresOnString)

@end
