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
#import "NSURL+MSIDExtensions.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSALAccount+Internal.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccessToken.h"
#import "MSIDIdToken.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDAccount.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacyAccessToken.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAccountIdentifier.h"

#define BAD_REFRESH_TOKEN @"bad-refresh-token"

@interface MSALTestAppCacheViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) MSIDAccountCredentialCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;

@end

@implementation MSALTestAppCacheViewController
{
    NSArray *_accounts;
    NSMutableDictionary<NSString *, NSMutableArray *> *_tokensPerAccount;
    UITableView *_cacheTableView;
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

    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    self.legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil factory:factory];
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:@[self.legacyAccessor] factory:factory];
    _tokenCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    
    return self;
}

- (void)deleteTokenAtPath:(NSIndexPath *)indexPath
{
    MSIDBaseToken *token = [self tokenForPath:indexPath];

    if (token)
    {
        switch (token.credentialType) {
            case MSIDRefreshTokenType:
            {
                if ([token isKindOfClass:[MSIDLegacyRefreshToken class]])
                {
                    [self.legacyAccessor validateAndRemoveRefreshToken:(MSIDLegacyRefreshToken *)token
                                                               context:nil
                                                                 error:nil];
                }
                else
                {
                    [self.defaultAccessor validateAndRemoveRefreshToken:(MSIDRefreshToken *)token
                                                                context:nil
                                                                  error:nil];
                }
                break;
            }
            case MSIDAccessTokenType:
            {
                if ([token isKindOfClass:[MSIDLegacyAccessToken class]])
                {
                    [self.legacyAccessor removeAccessToken:(MSIDLegacyAccessToken *)token context:nil error:nil];
                }
                else
                {
                    [self.defaultAccessor removeToken:token context:nil error:nil];
                }

                break;
            }
            default:
                [self.defaultAccessor removeToken:token context:nil error:nil];
                break;
        }
    }

    [self loadCache];
}

- (void)expireTokenAtPath:(NSIndexPath*)indexPath
{
    MSIDAccessToken *accessToken = (MSIDAccessToken *) [self tokenForPath:indexPath];
    accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];
    [_tokenCache saveCredential:accessToken.tokenCacheItem context:nil error:nil];
    [self loadCache];
}

- (void)deleteAllAtPath:(NSIndexPath *)indexPath
{
    MSIDAccount *account = _accounts[indexPath.section];

    [self.defaultAccessor clearCacheForAccount:account.accountIdentifier
                                   environment:nil
                                      clientId:nil
                                       context:nil
                                         error:nil];

    [self.legacyAccessor clearCacheForAccount:account.accountIdentifier
                                      context:nil
                                        error:nil];

    [self loadCache];
}

- (void)invalidateTokenAtPath:(NSIndexPath *)indexPath
{
    MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) [self tokenForPath:indexPath];
    refreshToken.refreshToken = BAD_REFRESH_TOKEN;
    [_tokenCache saveCredential:refreshToken.tokenCacheItem context:nil error:nil];
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
    
    [[NSNotificationCenter defaultCenter] addObserverForName:MSALTestAppCacheChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(__unused NSNotification * _Nonnull note)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadCache];
        });
    }];
}

- (void)loadCache
{
    [self.refreshControl beginRefreshing];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        _accounts = [self.defaultAccessor allAccountsForEnvironment:nil clientId:nil familyId:nil context:nil error:nil];
        _tokensPerAccount = [NSMutableDictionary dictionary];

        for (MSIDAccount *account in _accounts)
        {
            _tokensPerAccount[[self rowIdentifier:account.accountIdentifier]] = [NSMutableArray array];
        }

        NSMutableArray *allTokens = [[self.defaultAccessor allTokensWithContext:nil error:nil] mutableCopy];
        NSArray *legacyTokens = [self.legacyAccessor allTokensWithContext:nil error:nil];
        [allTokens addObjectsFromArray:legacyTokens];

        for (MSIDBaseToken *token in allTokens)
        {
            NSMutableArray *tokens = _tokensPerAccount[[self rowIdentifier:token.accountIdentifier]];
            [tokens addObject:token];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_cacheTableView reloadData];
            [self.refreshControl endRefreshing];
        });
    });
}

- (NSString *)rowIdentifier:(MSIDAccountIdentifier *)accountIdentifier
{
    return accountIdentifier.homeAccountId ? accountIdentifier.homeAccountId : accountIdentifier.legacyAccountId;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView
{
    return [_accounts count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    MSIDAccount *account = _accounts[section];
    return [_tokensPerAccount[[self rowIdentifier:account.accountIdentifier]] count] + 1;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    MSIDAccount *account = _accounts[section];
    NSString *title = [NSString stringWithFormat:@"%@ (%@)", account.username, [self rowIdentifier:account.accountIdentifier]];
    return title;
}

- (MSIDBaseToken *)tokenForPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= 1)
    {
        MSIDAccount *account = _accounts[indexPath.section];
        return _tokensPerAccount[[self rowIdentifier:account.accountIdentifier]][indexPath.row - 1];
    }

    return nil;
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

    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.textColor = [UIColor darkTextColor];

    MSIDBaseToken *token = [self tokenForPath:indexPath];

    if (!token)
    {
        MSIDAccount *account = _accounts[indexPath.section];
        cell.textLabel.text = account.authority.msidHostWithPortIfNecessary;
        cell.backgroundColor = [UIColor colorWithRed:0.27 green:0.43 blue:0.7 alpha:1.0];
        return cell;
    }

    switch (token.credentialType) {
        case MSIDRefreshTokenType:
        {
            MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) token;

            if ([token isKindOfClass:[MSIDLegacyRefreshToken class]])
            {
                cell.textLabel.text = [NSString stringWithFormat:@"[Legacy RT] %@, FRT %@", token.authority.msidTenant, refreshToken.clientId];
            }
            else
            {
                cell.textLabel.text = [NSString stringWithFormat:@"[RT] %@, FRT %@", refreshToken.authority.msidTenant, refreshToken.familyId];
            }

            if ([refreshToken.refreshToken isEqualToString:BAD_REFRESH_TOKEN])
            {
                cell.textLabel.textColor = [UIColor orangeColor];
            }
            break;
        }
        case MSIDAccessTokenType:
        {
            MSIDAccessToken *accessToken = (MSIDAccessToken *) token;
            cell.textLabel.text = [NSString stringWithFormat:@"[AT] %@/%@", [accessToken.scopes msidToString], accessToken.authority.msidTenant];

            if (accessToken.isExpired)
            {
                cell.textLabel.textColor = [UIColor redColor];
            }
            break;
        }
        case MSIDIDTokenType:
        {
            cell.textLabel.text = [NSString stringWithFormat:@"[ID] %@", token.authority.msidTenant];
            break;
        }
        case MSIDLegacySingleResourceTokenType:
        {
            cell.textLabel.text = @"Legacy single resource token";
            break;
        }
        default:
            break;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                           editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0)
    {
        return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                    title:@"Delete All"
                                                  handler:^(__unused UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
                  {
                      [self deleteAllAtPath:indexPath];
                  }]];
    }
    else
    {
        UITableViewRowAction *deleteTokenAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Delete"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
         {
             [self deleteTokenAtPath:indexPath];
         }];

        UITableViewRowAction* invalidateAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Invalidate"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
         {
             [self invalidateTokenAtPath:indexPath];
         }];

        [invalidateAction setBackgroundColor:[UIColor orangeColor]];

        UITableViewRowAction* expireTokenAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Expire"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
         {
             [self expireTokenAtPath:indexPath];
         }];
        [expireTokenAction setBackgroundColor:[UIColor orangeColor]];

        MSIDBaseToken *token = [self tokenForPath:indexPath];

        switch (token.credentialType)
        {
            case MSIDRefreshTokenType:
            {
                if ([token isKindOfClass:[MSIDLegacyRefreshToken class]])
                {
                    return @[deleteTokenAction];
                }

                return @[deleteTokenAction, invalidateAction];
            }
            case MSIDAccessTokenType:
            {
                return @[deleteTokenAction, expireTokenAction];
            }
            case MSIDIDTokenType:
            {
                return @[deleteTokenAction];
            }
            default:
                return nil;
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
