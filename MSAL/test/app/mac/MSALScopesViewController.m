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

#import "MSALScopesViewController.h"
#import "MSALTestAppSettings.h"

@interface MSALScopesViewController ()
@property NSMutableArray *scopesList;
@property (weak) IBOutlet NSTableView *scopesView;
@property (weak) IBOutlet NSTextField *scopesText;

@end

@implementation MSALScopesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.scopesView.delegate = self;
    self.scopesView.dataSource = self;
    [self.scopesView setAllowsMultipleSelection: YES];
    self.scopesList = [[NSMutableArray alloc] init];
    [self.scopesList addObjectsFromArray:[MSALTestAppSettings availableScopes]];
    [self.scopesView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.scopesList count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *scope = [self.scopesList objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"ScopesCell"])
    {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        [cellView.textField setStringValue:scope];
        return cellView;
    }
    return nil;
}

- (IBAction)insertNewRow:(id)sender
{
    NSString *scope = [self.scopesText stringValue];
    
    if (scope.length > 0  && ![self.scopesList containsObject:scope])
    {
        NSInteger selectedRow = [self.scopesView selectedRow];
        selectedRow++;
        [self.scopesList insertObject:scope atIndex:selectedRow];
        [self.scopesView beginUpdates];
        [self.scopesView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:selectedRow] withAnimation:NSTableViewAnimationEffectGap];
        [self.scopesView scrollRowToVisible:selectedRow];
        [self.scopesView endUpdates];
    }
}

- (IBAction)deleteSelectedRows:(id)sender
{
    NSIndexSet *indexes = [self.scopesView selectedRowIndexes];
    [self.scopesList removeObjectsAtIndexes:indexes];
    [self.scopesView removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
}

- (IBAction)done:(id)sender
{
    NSIndexSet *indexes = [self.scopesView selectedRowIndexes];
    NSMutableArray *selectedScopes = [[NSMutableArray alloc] init];
    [selectedScopes addObjectsFromArray:[self.scopesList objectsAtIndexes:indexes]];
    [self.delegate setScopes:selectedScopes];
    [self dismissViewController:self];
}


@end
