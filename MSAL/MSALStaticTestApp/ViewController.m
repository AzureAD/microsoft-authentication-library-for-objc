//
//  ViewController.m
//  MSALStaticTestApp
//
//  Created by Olga Dalton on 4/5/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "ViewController.h"
#import <MSAL/MSAL.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:@"test" error:nil];
    NSLog(@"App: %@", app);
}


@end
