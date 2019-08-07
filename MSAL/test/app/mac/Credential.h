//
//  Credential.h
//  MSAL Test App (Mac)
//
//  Created by Rohit Narula on 8/6/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Credential : NSObject

@property NSString *name;
@property int age;
@property NSMutableArray *children;

- (instancetype)initWithName:(NSString *)name age:(int)age;
- (void)addChild:(Credential *)cred;

@end

NS_ASSUME_NONNULL_END
