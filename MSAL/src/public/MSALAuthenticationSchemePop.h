//
//  MSALPopAuthenticationScheme.h
//  MSAL
//
//  Created by Rohit Narula on 5/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSALAuthenticationScheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSALAuthenticationSchemePop : MSALAuthenticationScheme

@property (nonatomic) MSALHttpMethod httpMethod;
@property (nonatomic) NSURL *requestUrl;
@property (nonatomic, nullable) NSString *nonce;

- (instancetype)initWithHttpMethod:(MSALHttpMethod)httpMethod requestUrl:(NSURL *)requestUrl;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
