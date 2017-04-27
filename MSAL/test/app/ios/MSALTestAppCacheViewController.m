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

#import "MSALTestAppCacheViewController.h"
#import "MSALTestAppSettings.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALKeychainTokenCache.h"
#import "MSALAccessTokenCacheItem+TestAppUtil.h"
#import "NSURL+MSALExtensions.h"

@interface MSALTestAppCacheRowItem : NSObject

@property BOOL environment;
@property MSALBaseTokenCacheItem *item;
@property NSString *title;

@end

@implementation MSALTestAppCacheRowItem

@end

@interface MSALTestAppCacheViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation MSALTestAppCacheViewController

#define BAD_REFRESH_TOKEN @"bad-refresh-token"

{
    UITableView *_cacheTableView;
    
    NSMutableDictionary *_cacheMap;
    
    NSMutableDictionary *_userMap;
    
    NSMutableArray *_userIdentifiers;
    NSMutableArray *_userTokens;
    
    NSArray *_tokenRowActions;
    NSArray *_rtRowActions;
    NSArray *_environmentRowActions;
}

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStylePlain]))
    {
        return nil;
    }
    
    UITabBarItem* tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Cache" image:nil tag:0];
    [self setTabBarItem:tabBarItem];
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    [self setExtendedLayoutIncludesOpaqueBars:NO];
    [self setAutomaticallyAdjustsScrollViewInsets:NO];
    
    return self;
}

- (void)deleteTokenAtPath:(NSIndexPath*)indexPath
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];
    
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    if ([rowItem.item isKindOfClass:[MSALAccessTokenCacheItem class]])
    {
        [cache removeAccessTokenItem:(MSALAccessTokenCacheItem *)rowItem.item context:nil error:nil];
    }
    else if ([rowItem.item isKindOfClass:[MSALRefreshTokenCacheItem class]])
    {
        [cache removeRefreshTokenItem:(MSALRefreshTokenCacheItem *)rowItem.item context:nil error:nil];
    }
    
    [self loadCache];
}

- (void)expireTokenAtPath:(NSIndexPath*)indexPath
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];
    if (![rowItem.item isKindOfClass:[MSALAccessTokenCacheItem class]])
    {
        return;
    }
    
    MSALAccessTokenCacheItem *item = (MSALAccessTokenCacheItem *)rowItem.item;
    item.expiresOnString = [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:-1.0] timeIntervalSince1970]];
    
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    [cache addOrUpdateAccessTokenItem:item context:nil error:nil];
    
    [self loadCache];
}

- (void)deleteAllAtPath:(NSIndexPath *)indexPath
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];
    if (!rowItem.environment)
    {
        NSLog(@"Trying to delete all from a non-client-id item?");
        return;
    }
    
    NSString *userId = [_userIdentifiers objectAtIndex:indexPath.section];
    
    // Delete all tokens
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    [cache removeAllTokensForUserIdentifier:userId environment:rowItem.title clientId:TEST_APP_CLIENT_ID context:nil error:nil];
    
    [_userMap removeObjectForKey:userId];
    [_userTokens removeObjectAtIndex:indexPath.section];
    
    [self loadCache];
}

- (void)invalidateTokenAtPath:(NSIndexPath*)indexPath
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];
    if (![rowItem.item isKindOfClass:[MSALRefreshTokenCacheItem class]])
    {
        return;
    }
    
    MSALRefreshTokenCacheItem *item = (MSALRefreshTokenCacheItem *)rowItem.item;
    item.refreshToken = BAD_REFRESH_TOKEN;
    
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    [cache addOrUpdateRefreshTokenItem:item context:nil error:nil];
    
    [self loadCache];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self loadCache];
    
    _cacheTableView = self.tableView;
    [_cacheTableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [_cacheTableView setDelegate:self];
    [_cacheTableView setDataSource:self];
    [_cacheTableView setAllowsSelection:NO];
    
    // Move the content down so it's not covered by the status bar
    [_cacheTableView setContentInset:UIEdgeInsetsMake(20, 0, 0, 0)];
    [_cacheTableView setContentOffset:CGPointMake(0, -20)];
    
    UIRefreshControl* refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(loadCache) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    UITableViewRowAction* deleteTokenAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                       title:@"Delete"
                                     handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
    {
        (void)action;
        [self deleteTokenAtPath:indexPath];
    }];
    
    UITableViewRowAction* invalidateAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                       title:@"Invalidate"
                                     handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
     {
         (void)action;
         [self invalidateTokenAtPath:indexPath];
     }];
    [invalidateAction setBackgroundColor:[UIColor orangeColor]];
    
    UITableViewRowAction* expireTokenAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                       title:@"Expire"
                                     handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
    {
        (void)action;
        [self expireTokenAtPath:indexPath];
    }];
    [expireTokenAction setBackgroundColor:[UIColor orangeColor]];
    
    
    UITableViewRowAction* deleteAllAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                       title:@"Delete All"
                                     handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
    {
        (void)action;
        [self deleteAllAtPath:indexPath];
    }];
    
    _tokenRowActions = @[ deleteTokenAction, expireTokenAction ];
    _rtRowActions = @[ deleteTokenAction, invalidateAction ];
    _environmentRowActions = @[ deleteAllAction ];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:MSALTestAppCacheChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note)
    {
        (void)note;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadCache];
        });
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addTokenToCacheMap:(MSALBaseTokenCacheItem *)item
{
    NSString *userId = item.user.userIdentifier;
    
    NSMutableDictionary *userTokens = _cacheMap[userId];
    if (!userTokens)
    {
        userTokens = [NSMutableDictionary new];
        [_cacheMap setObject:userTokens forKey:userId];
    }
    
    NSString *environment = item.user.environment;
    
    NSMutableArray *environmentTokens = userTokens[environment];
    if (!environmentTokens)
    {
        environmentTokens = [NSMutableArray new];
        userTokens[environment] = environmentTokens;
    }
    
    [environmentTokens addObject:item];
}

- (void)loadCache
{
    [self.refreshControl beginRefreshing];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // First create a map heirarchy of userId -> clientId -> tokens to sort
        // through all the itmes we get back
        MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
        _cacheMap = [NSMutableDictionary new];
        
        NSArray *allAccessTokenItems = [cache getAccessTokenItemsWithKey:nil context:nil error:nil];
        for (MSALBaseTokenCacheItem* item in allAccessTokenItems)
        {
            [self addTokenToCacheMap:item];
        }
        
        NSArray *allRefreshTokenItems = [cache allRefreshTokens:nil context:nil error:nil];
        for (MSALBaseTokenCacheItem* item in allRefreshTokenItems)
        {
            [self addTokenToCacheMap:item];
        }
        
        // Now that we have all the items sorted out in the dictionaries flatten it
        // out to a single list.
        _userIdentifiers = [[NSMutableArray alloc] initWithCapacity:_cacheMap.count];
        _userTokens = [[NSMutableArray alloc] initWithCapacity:_cacheMap.count];
        _userMap = [NSMutableDictionary new];
        
        for (NSString *userId in _cacheMap)
        {
            NSUInteger count = 0;
            [_userIdentifiers addObject:userId];
            
            NSDictionary *userTokens = _cacheMap[userId];
            for (NSString* key in userTokens)
            {
                count += [[userTokens objectForKey:key] count]  + 1; // Add one for the "client ID" item
            }
            
            NSMutableArray* arrUserTokens = [[NSMutableArray alloc] initWithCapacity:count];

            for (NSString *environment in userTokens)
            {
                // Add environment row
                MSALTestAppCacheRowItem *environmentItem = [MSALTestAppCacheRowItem new];
                environmentItem.title = environment;
                environmentItem.environment = YES;
                
                [arrUserTokens addObject:environmentItem];
                
                NSArray *environmentTokens = userTokens[environment];
                for (MSALBaseTokenCacheItem *item in environmentTokens)
                {
                    
                    MSALTestAppCacheRowItem* tokenItem = [MSALTestAppCacheRowItem new];
                    if ([item isKindOfClass:[MSALAccessTokenCacheItem class]])
                    {
                        tokenItem.title = ((MSALAccessTokenCacheItem *)item).scope.msalToString;
                    }
                    else if ([item isKindOfClass:[MSALRefreshTokenCacheItem class]])
                    {
                        tokenItem.title = @"RT";
                    }
                    tokenItem.item = item;
                    [arrUserTokens addObject:tokenItem];
                    
                    _userMap[userId] = item.user.displayableId;
                }
            }
            
            [_userTokens addObject:arrUserTokens];
            
        }
        _cacheMap = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_cacheTableView reloadData];
            [self.refreshControl endRefreshing];
            
            if (!_userMap[MSALTestAppSettings.settings.currentUser.userIdentifier])
            {
                MSALTestAppSettings.settings.currentUser = nil;
            }
        });
    });
}

- (MSALTestAppCacheRowItem*)cacheItemForPath:(NSIndexPath*)indexPath
{
    return [[_userTokens objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    (void)tableView;
    return [_userIdentifiers count];
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    (void)tableView;
    return _userMap[[_userIdentifiers objectAtIndex:section]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    return [[_userTokens objectAtIndex:section] count];
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cacheCell"];
    
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cacheCell"];
    }
    
    MSALTestAppCacheRowItem* cacheItem = [self cacheItemForPath:indexPath];
    
    if (cacheItem.environment)
    {
        [cell setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:((CGFloat)0x80/(CGFloat)0xFF) alpha:1.0]];
        [[cell textLabel] setTextColor:[UIColor whiteColor]];
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
    }
    else
    {
        [cell setBackgroundColor:[UIColor whiteColor]];

        if ([cacheItem.item isKindOfClass:[MSALRefreshTokenCacheItem class]] &&
             [((MSALRefreshTokenCacheItem *)cacheItem.item).refreshToken isEqualToString:BAD_REFRESH_TOKEN])
        {
            [[cell textLabel] setTextColor:[UIColor orangeColor]];
        }
        else if ([cacheItem.item isKindOfClass:[MSALAccessTokenCacheItem class]] &&
                 ((MSALAccessTokenCacheItem *)cacheItem.item).isExpired)
        {
            [[cell textLabel] setTextColor:[UIColor orangeColor]];
        }
        else
        {
            [[cell textLabel] setTextColor:[UIColor blackColor]];
        }
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
    }
    
    [[cell textLabel] setText:cacheItem.title];
    
    return cell;
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                           editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    
    MSALTestAppCacheRowItem* rowItem = [self cacheItemForPath:indexPath];
    (void)rowItem;
    
    if (rowItem.environment)
    {
        return _environmentRowActions;
    }
    else
    {
        if ([rowItem.item isKindOfClass:[MSALAccessTokenCacheItem class]])
        {
            return _tokenRowActions;
        }
        else if ([rowItem.item isKindOfClass:[MSALRefreshTokenCacheItem class]])
        {
            return _rtRowActions;
        }
    }
    
    return nil;
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // All tasks are handled by blocks defined in editActionsForRowAtIndexPath, however iOS8 requires this method to enable editing
    (void)tableView;
    (void)editingStyle;
    (void)indexPath;
}


@end
