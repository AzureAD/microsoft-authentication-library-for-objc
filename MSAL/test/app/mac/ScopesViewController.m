//
//  ScopesViewController.m
//  MSALMacTestApp
//
//  Created by Rohit Narula on 4/5/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "ScopesViewController.h"
#import "MSALTestAppSettings.h"


@interface ScopesViewController ()
@property (weak) IBOutlet NSTableView *scopesView;
@property NSArray<NSString*> *scopes;
@property NSMutableArray<NSString *> *selectedScopes;
@end

@implementation ScopesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.scopesView.delegate = self;
    self.scopesView.dataSource = self;
    [self.scopesView setAllowsMultipleSelection: YES];
    self.scopes = @[@"User.Read", @"Tasks.Read", @"https://graph.microsoft.com/.default",@"https://msidlabb2c.onmicrosoft.com/msidlabb2capi/read", @"Tasks.Read"];
    self.selectedScopes = [[NSMutableArray alloc] init];
    [self.scopesView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.scopes count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    result.textField.stringValue = [self.scopes objectAtIndex:row];
    return result;
}

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
    NSLog(@"%@",indexes);
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSIndexSet *scopeSet = self.scopesView.selectedRowIndexes;
    [scopeSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [self.selectedScopes addObject:[self.scopes objectAtIndex:idx]];
    }];
    NSLog(@"%@",self.selectedScopes);
}

@end
