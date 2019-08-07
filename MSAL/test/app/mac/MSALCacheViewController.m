//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALCacheViewController.h"
#import <MSAL/MSAL.h>
#import "MSIDAccountCredentialCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDMacKeychainTokenCache.h"

static NSString *s_defaultKeychainGroup = @"com.microsoft.identity.universalstorage";

@interface MSALCacheViewController ()
@property (weak) IBOutlet NSOutlineView *outLineView;
@property (nonatomic) MSIDAccountCredentialCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;
@property (strong) NSArray *accounts;

@end

@implementation MSALCacheViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:MSIDMacKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil];
    _defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDMacKeychainTokenCache.defaultKeychainCache otherCacheAccessors:@[self.legacyAccessor]];
    _tokenCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDMacKeychainTokenCache.defaultKeychainCache];
    
    self.accounts = [self.defaultAccessor accountsWithAuthority:nil
                                                         clientId:nil
                                                         familyId:nil
                                                accountIdentifier:nil
                                                          context:nil
                                                            error:nil];

    NSLog(@"%@",self.accounts);
    
//    NSString *accessGroup = [MSIDKeychainUtil accessGroup];
    _credentials = [[NSMutableArray alloc] init];
    Credential *boss = [[Credential alloc] initWithName:@"Yoda" age:10];
    [boss addChild:[[Credential alloc] initWithName:@"Stephen" age:20]];
    [boss addChild:[[Credential alloc] initWithName:@"Taylor" age:30]];
    [boss addChild:[[Credential alloc] initWithName:@"Jessie" age:40]];
    [(Credential *)[boss.children objectAtIndex:0] addChild:[[Credential alloc] initWithName:@"Lucas" age:40]];
    
    [(Credential *)[boss.children objectAtIndex:1] addChild:[[Credential alloc] initWithName:@"Roman" age:40]];
    
    [(Credential *)[boss.children objectAtIndex:2] addChild:[[Credential alloc] initWithName:@"Nathan" age:50]];
    [_credentials addObject:boss];
    self.outLineView.delegate = self;
    self.outLineView.dataSource = self;
    [self.outLineView reloadData];
    
    // Do view setup here.
}


#pragma mark Helper Methods

#pragma mark NSOutlineView Data Source Methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return !item ? [self.credentials count] : [[item children] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return !item ? YES : [[item children] count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    return !item ? [self.credentials objectAtIndex:index] : [[item children] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    Credential *person = (Credential *)item;
    if ([[tableColumn identifier] isEqualToString:@"name"])
    {
        NSLog(@"%@",[person name]);
        return [person name];
    }
    else if([[tableColumn identifier] isEqualToString:@"age"])
    {
        NSLog(@"%@",@([person age]));
        return @([person age]);
    }
    else
    {
        return @"Nobody's here";
    }
}

@end
