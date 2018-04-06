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
#import "MSALKeychainTokenCache.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDSharedTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSALUser+Internal.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccessToken.h"
#import "MSIDIdToken.h"
#import "MSIDDefaultTokenCacheKey.h"
#import "MSIDJsonSerializer.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheKey.h"

#define BAD_REFRESH_TOKEN @"bad-refresh-token"

@interface MSALTestAppCacheRowItem : NSObject

@property BOOL environment;
@property MSIDBaseToken *item;
@property NSString *title;
@property (nonatomic) BOOL isLegacy;

@end

@implementation MSALTestAppCacheRowItem

@end

@interface MSALTestAppCacheViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) MSIDSharedTokenCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;

@end

@implementation MSALTestAppCacheViewController

{
    UITableView *_cacheTableView;
    
    NSMutableDictionary *_cacheMap;
    
    NSMutableDictionary *_userMap;
    
    NSMutableArray *_userIdentifiers;
    NSMutableArray *_userTokens;
    
    NSArray *_tokenRowActions;
    NSArray *_rtRowActions;
    NSArray *_idTokenRowActions;
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
    
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    self.legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    _tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:self.defaultAccessor otherCacheAccessors:@[self.legacyAccessor]];
    
    return self;
}

- (void)deleteTokenAtPath:(NSIndexPath*)indexPath isLegacy:(BOOL)isLegacy
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];

    MSIDBaseToken *token = (MSIDBaseToken *)rowItem.item;
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil uniqueUserId:token.uniqueUserId];
    if (isLegacy)
    {
        [self.legacyAccessor removeToken:token account:account context:nil error:nil];
    }
    else
    {
        [self.defaultAccessor removeToken:token account:account context:nil error:nil];
    }

    [self loadCache];
}

- (void)expireTokenAtPath:(NSIndexPath*)indexPath
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];

    if (![rowItem.item isKindOfClass:[MSIDAccessToken class]]) return;

    MSIDAccessToken *token = (MSIDAccessToken *)rowItem.item;
    token.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];

    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    MSIDTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccessTokenWithUniqueUserId:token.uniqueUserId
                                                             authority:token.authority
                                                              clientId:token.clientId
                                                                scopes:[cacheItem.target scopeSet]];
    
    [MSIDKeychainTokenCache.defaultKeychainCache saveToken:cacheItem
                                                       key:key
                                                serializer:[MSIDJsonSerializer new]
                                                   context:nil
                                                     error:nil];
    
    

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
    NSMutableArray *tokens = _userTokens[indexPath.section];
    
    if (tokens.count > 1)
    {
        // Get 2nd cache item, 1st is envirment title.
        MSALTestAppCacheRowItem *cacheItem = tokens[1];
        
        MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil uniqueUserId:userId];
        account.authority = cacheItem.item.authority;
        [self.defaultAccessor removeAllTokensForAccount:account context:nil error:nil];
        [self.legacyAccessor removeAllTokensForAccount:account context:nil error:nil];
        [self.defaultAccessor removeAccount:account context:nil error:nil];
        
        [_userMap removeObjectForKey:userId];
        [_userTokens removeObjectAtIndex:indexPath.section];
        
        [self loadCache];
    }
}

- (void)invalidateTokenAtPath:(NSIndexPath*)indexPath isLegacy:(BOOL)isLegacy
{
    MSALTestAppCacheRowItem *rowItem = [self cacheItemForPath:indexPath];
    if (![rowItem.item isKindOfClass:[MSIDRefreshToken class]])
    {
        return;
    }

    MSIDRefreshToken *token = (MSIDRefreshToken *)rowItem.item;
    token.refreshToken = BAD_REFRESH_TOKEN;

    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    if (isLegacy)
    {
        // not implemented.
    }
    else
    {
        MSIDTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForRefreshTokenWithUniqueUserId:token.uniqueUserId
                                                                                  environment:token.authority.msidHostWithPortIfNecessary
                                                                                     clientId:token.clientId];
        
        [MSIDKeychainTokenCache.defaultKeychainCache saveToken:cacheItem
                                                           key:key
                                                    serializer:[MSIDJsonSerializer new]
                                                       context:nil
                                                         error:nil];
    }

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
        MSALTestAppCacheRowItem *item = [self cacheItemForPath:indexPath];
        [self deleteTokenAtPath:indexPath isLegacy:item.isLegacy];
    }];
    
    UITableViewRowAction* invalidateAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                       title:@"Invalidate"
                                     handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
     {
         (void)action;
         MSALTestAppCacheRowItem *item = [self cacheItemForPath:indexPath];
         [self invalidateTokenAtPath:indexPath isLegacy:item.isLegacy];
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
    _idTokenRowActions = @[deleteTokenAction];
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

- (void)addTokenToCacheMap:(MSIDBaseToken *)item
{
    NSString *userId = item.uniqueUserId;
    
    NSMutableDictionary *userTokens = _cacheMap[userId];
    if (!userTokens)
    {
        userTokens = [NSMutableDictionary new];
        [_cacheMap setObject:userTokens forKey:userId];
    }
    
    NSString *environment = item.authority.msidHostWithPortIfNecessary;
    
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
        _cacheMap = [NSMutableDictionary new];
        
        NSMutableArray *allItems = [[self.defaultAccessor allTokensWithContext:nil error:nil] mutableCopy];
        NSArray *legacyItems = [self.legacyAccessor allTokensWithContext:nil error:nil];
        [allItems addObjectsFromArray:legacyItems];
        
        for (MSIDBaseToken *item in allItems)
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
                for (MSIDBaseToken *item in environmentTokens)
                {
                    MSALTestAppCacheRowItem* tokenItem = [MSALTestAppCacheRowItem new];
                    tokenItem.isLegacy = [legacyItems indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop)
                    {
                        return (BOOL)(obj == item);
                    }] != NSNotFound;
                    
                    if ([item isKindOfClass:[MSIDAccessToken class]])
                    {
                        tokenItem.title = ((MSIDAccessToken *)item).scopes.msalToString;
                    }
                    else if ([item isKindOfClass:[MSIDRefreshToken class]])
                    {
                        tokenItem.title = tokenItem.isLegacy ? @"RT in legacy format" : @"RT";
                    }
                    else if ([item isKindOfClass:[MSIDIdToken class]])
                    {
                        tokenItem.title = @"ID token";
                    }
                    tokenItem.item = item;
                    [arrUserTokens addObject:tokenItem];
                    
                    _userMap[userId] = item.username;
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

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    (void)tableView;
    return [_userIdentifiers count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    return [[_userTokens objectAtIndex:section] count];
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    (void)tableView;
    return _userMap[[_userIdentifiers objectAtIndex:section]];
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
    
    MSALTestAppCacheRowItem *cacheItem = [self cacheItemForPath:indexPath];
    
    if (cacheItem.environment)
    {
        [cell setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:((CGFloat)0x80/(CGFloat)0xFF) alpha:1.0]];
        [[cell textLabel] setTextColor:[UIColor whiteColor]];
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
    }
    else
    {
        [cell setBackgroundColor:[UIColor whiteColor]];

        if ([cacheItem.item isKindOfClass:[MSIDRefreshToken class]] &&
             [((MSIDRefreshToken *)cacheItem.item).refreshToken isEqualToString:BAD_REFRESH_TOKEN])
        {
            [[cell textLabel] setTextColor:[UIColor orangeColor]];
        }
        else if ([cacheItem.item isKindOfClass:[MSIDAccessToken class]] &&
                 ((MSIDAccessToken *)cacheItem.item).isExpired)
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

#pragma mark - UITableViewDelegate

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
        if ([rowItem.item isKindOfClass:[MSIDAccessToken class]])
        {
            return _tokenRowActions;
        }
        else if ([rowItem.item isKindOfClass:[MSIDRefreshToken class]])
        {
            return _rtRowActions;
        }
        else if ([rowItem.item isKindOfClass:[MSIDIdToken class]])
        {
            return _idTokenRowActions;
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
