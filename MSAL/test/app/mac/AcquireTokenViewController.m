//
//  AcquireTokenViewController.m
//  MSALMacTestApp
//
//  Created by Rohit Narula on 4/3/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "AcquireTokenViewController.h"
#import <MSAL/MSAL.h>
#import "MSALTestAppSettings.h"

static NSString * const clientId = @"clientId";
static NSString * const redirectUri = @"redirectUri";


@interface AcquireTokenViewController ()

@property (weak) IBOutlet NSPopUpButton *profiles;
@property (weak) IBOutlet NSTextField *clientId;
@property (weak) IBOutlet NSTextField *redirectUri;
@property (weak) IBOutlet NSSegmentedControl *promptBehavior;

@end

@implementation AcquireTokenViewController

- (IBAction)selectScopes:(id)sender
{
    
}

- (IBAction)acquireTokenInteractive:(id)sender
{
    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:@"1234" error:nil];
    NSLog(@"%@",app);
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self populateProfiles];
    // Do view setup here.
}

- (void)populateProfiles
{
    [self.profiles removeAllItems];
    [self.profiles setTarget:self];
    [self.profiles setAction:@selector(selectedProfileChanged:)];
    [[MSALTestAppSettings profiles] enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        [self.profiles addItemWithTitle:key];
    }];

    NSDictionary* currentProfile = [[MSALTestAppSettings settings] profile];
    NSArray *profiles = [[MSALTestAppSettings profiles] allKeysForObject:currentProfile];
    [self.profiles selectItemWithTitle:[profiles firstObject]];
    self.clientId.stringValue = [currentProfile objectForKey:clientId];
    self.redirectUri.stringValue = [currentProfile objectForKey:redirectUri];
}

- (IBAction)selectedProfileChanged:(id)sender
{
    NSString *currentProfile = [self.profiles titleOfSelectedItem];
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    [settings setProfile:[[MSALTestAppSettings profiles] objectForKey:currentProfile]];
    self.clientId.stringValue = [settings.profile objectForKey:clientId];
    self.redirectUri.stringValue = [settings.profile objectForKey:redirectUri];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    
}

@end
