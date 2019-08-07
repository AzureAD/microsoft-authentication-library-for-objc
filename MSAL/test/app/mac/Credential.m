//
//  Credential.m
//  MSAL Test App (Mac)
//
//  Created by Rohit Narula on 8/6/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "Credential.h"

@implementation Credential

- (instancetype)init
{
    return [self initWithName:@"Rohit" age:10];
}

- (instancetype)initWithName:(NSString *)name age:(int)age
{
    self = [super init];
    if (self)
    {
        _name = name;
        _age = age;
        _children = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)addChild:(Credential *)cred
{
    [self.children addObject:cred];
}

@end
