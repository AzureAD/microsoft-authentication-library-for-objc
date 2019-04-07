//
//  ScopesViewController.h
//  MSALMacTestApp
//
//  Created by Rohit Narula on 4/5/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ScopesDelegate <NSObject>
- (void)setScopes:(NSMutableArray *)scopes;
@end

@interface ScopesViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

@property (weak) id<ScopesDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
