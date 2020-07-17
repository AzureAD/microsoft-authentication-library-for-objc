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
#import "MSIDAuthority.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDConfiguration.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDConstants.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDAssymetricKeyKeychainGenerator+Internal.h"
#import "MSALTestAppAsymmetricKey.h"
#import "MSIDDevicePopManager+Internal.h"
#import "MSIDCacheConfig.h"
#import "MSIDAssymetricKeyPair.h"
#import "MSIDAuthScheme.h"
#import "MSALCacheItemDetailViewController.h"
#import "MSIDMetadataCache.h"
#import "MSIDAccountMetadataCacheItem.h"
#import "MSIDAccountMetadataCacheKey.h"

#define BAD_REFRESH_TOKEN @"bad-refresh-token"
#define APP_METADATA @"App-Metadata"
#define ACCOUNT_METADATA @"Account-Metadata"
#define POP_TOKEN_KEYS @"RSA Key-Pair"
static NSString *const s_defaultAuthorityUrlString = @"https://login.microsoftonline.com/common";

@interface MSALTestAppCacheViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) MSIDAccountCredentialCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;
@property (strong) NSArray *accounts;
@property (strong) NSArray *appMetadataEntries;
@property (strong) NSMutableArray *accountMetadataEntries;
@property (nonatomic) MSIDAssymetricKeyLookupAttributes *keyPairAttributes;
@property (nonatomic) MSIDAssymetricKeyKeychainGenerator *keyGenerator;
@property (nonatomic) NSMutableArray *tokenKeys;
@property (nonatomic) MSIDDevicePopManager *popManager;
@property (nonatomic) MSIDCacheConfig *cacheConfig;
@property (nonatomic) NSString *keychainSharingGroup;
@property (nonatomic) MSIDMetadataCache *metadataCache;

@end

@implementation MSALTestAppCacheViewController
{
    NSMutableDictionary<NSString *, NSMutableArray *> *_tokensPerAccount;
    NSMutableDictionary *_cacheSections;
    NSMutableArray *_cacheSectionTitles;
    UITableView *_cacheTableView;
}

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
    {
        return nil;
    }
    
    UITabBarItem* tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Cache" image:nil tag:0];
    [self setTabBarItem:tabBarItem];
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    [self setExtendedLayoutIncludesOpaqueBars:NO];
#if TARGET_OS_MACCATALYST
    _cacheTableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
#else
    [self setAutomaticallyAdjustsScrollViewInsets:NO];
#endif
    
    self.legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil];
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:@[self.legacyAccessor]];
    self.metadataCache = [[MSIDMetadataCache alloc] initWithPersistentDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    _tokenCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    
    _keyPairAttributes = [MSIDAssymetricKeyLookupAttributes new];
    _keyPairAttributes.privateKeyIdentifier = MSID_POP_TOKEN_PRIVATE_KEY;
    _keyPairAttributes.publicKeyIdentifier = MSID_POP_TOKEN_PUBLIC_KEY;
    _keyPairAttributes.keyDisplayableLabel = MSID_POP_TOKEN_KEY_LABEL;

    _keychainSharingGroup = [MSIDKeychainTokenCache defaultKeychainGroup];
    _keyGenerator = [[MSIDAssymetricKeyKeychainGenerator alloc] initWithGroup:_keychainSharingGroup error:nil];
    
    _cacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:_keychainSharingGroup];
    _popManager = [[MSIDDevicePopManager alloc] initWithCacheConfig:_cacheConfig keyPairAttributes:_keyPairAttributes];
    return self;
}

- (void)deleteAppMetadata:(MSIDAppMetadataCacheItem *)appMetadata
{
    if (appMetadata)
    {
        [_tokenCache removeAppMetadata:appMetadata context:nil error:nil];
        [self loadCache];
    }
}

- (void)deleteAccountMetadata:(MSIDAccountMetadataCacheItem *)accountMetadata
{
    if (accountMetadata)
    {
        MSIDAccountMetadataCacheKey *key = [[MSIDAccountMetadataCacheKey alloc] initWithClientId:accountMetadata.clientId];
        [self.metadataCache removeAccountMetadataCacheItemForKey:key context:nil error:nil];
        [self loadCache];
    }
}

- (void)deleteKey:(MSALTestAppAsymmetricKey *)key
{
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                                  (__bridge id)kSecClassKey, (__bridge id)kSecClass,
                                  [key.name dataUsingEncoding:NSUTF8StringEncoding], (__bridge id)kSecAttrApplicationTag,
                                  (__bridge id)kSecAttrKeyTypeRSA, (__bridge id)kSecAttrKeyType,
                                  nil];
    
    [self.keyGenerator deleteItemWithAttributes:query itemTitle:nil error:nil];
    
    [self.tokenKeys removeObject:key];
    [self loadCache];
}

- (void)deleteToken:(MSIDBaseToken *)token
{
    if (token)
    {
        switch (token.credentialType)
        {
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
            case MSIDAccessTokenWithAuthSchemeType:
            {
                [self.defaultAccessor removeToken:(MSIDAccessTokenWithAuthScheme *)token context:nil error:nil];
                break;
            }
            default:
                [self.defaultAccessor removeToken:token context:nil error:nil];
                break;
        }
        
        [self loadCache];
    }
}

- (void)expireAccessToken:(MSIDAccessToken *)accessToken
{
    if (accessToken)
    {
        accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];
        [_tokenCache saveCredential:accessToken.tokenCacheItem context:nil error:nil];
        [self loadCache];
    }
}

- (void)deleteAllEntriesForAccount:(MSIDAccount *)account
{
    if (account)
    {
        [self.defaultAccessor clearCacheForAccount:account.accountIdentifier
                                         authority:nil
                                          clientId:nil
                                          familyId:nil
                                           context:nil
                                             error:nil];
        
        [self.legacyAccessor clearCacheForAccount:account.accountIdentifier
                                        authority:nil
                                         clientId:nil
                                         familyId:nil
                                          context:nil
                                            error:nil];
        
        [self loadCache];
    }
}

- (void)invalidateRefreshToken:(MSIDRefreshToken *)refreshToken
{
    if (refreshToken)
    {
        refreshToken.refreshToken = BAD_REFRESH_TOKEN;
        [_tokenCache saveCredential:refreshToken.tokenCacheItem context:nil error:nil];
        [self loadCache];
    }
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
        
        [self setAccounts:[self.defaultAccessor accountsWithAuthority:nil
                                                             clientId:nil
                                                             familyId:nil
                                                    accountIdentifier:nil
                                                              context:nil
                                                                error:nil]];
        
        [self setAppMetadataEntries:[self.defaultAccessor getAppMetadataEntries:nil context:nil error:nil]];
        
        _cacheSections = [NSMutableDictionary dictionary];
        if ([[self appMetadataEntries] count])
        {
            [_cacheSections setObject:[self appMetadataEntries] forKey:APP_METADATA];
            self.accountMetadataEntries = [NSMutableArray new];
            for (MSIDAppMetadataCacheItem *item in self.appMetadataEntries)
            {
                MSIDAccountMetadataCacheKey *key = [[MSIDAccountMetadataCacheKey alloc] initWithClientId:item.clientId];
                MSIDAccountMetadataCacheItem *accountMetadata = [self.metadataCache accountMetadataCacheItemWithKey:key context:nil error:nil];
                if (accountMetadata)
                {
                    [self.accountMetadataEntries addObject:accountMetadata];
                }
            }
        }
        
        if ([[self accountMetadataEntries] count])
        {
            [_cacheSections setObject:[self accountMetadataEntries] forKey:ACCOUNT_METADATA];
        }
        
        for (MSIDAccount *account in [self accounts])
        {
            _cacheSections[[self rowIdentifier:account.accountIdentifier]] = [NSMutableArray array];
            [_cacheSections[[self rowIdentifier:account.accountIdentifier]] addObject:account];
        }
        
        NSMutableArray *allTokens = [[self.defaultAccessor allTokensWithContext:nil error:nil] mutableCopy];
        NSArray *legacyTokens = [self.legacyAccessor allTokensWithContext:nil error:nil];
        [allTokens addObjectsFromArray:legacyTokens];
        
        BOOL isPopToken = NO;
        for (MSIDBaseToken *token in allTokens)
        {
            if ([token isKindOfClass:[MSIDAccessTokenWithAuthScheme class]])
            {
                MSIDAccessTokenWithAuthScheme *accessToken = (MSIDAccessTokenWithAuthScheme *)token;
                if(MSIDAuthSchemeTypeFromString(accessToken.tokenType) == MSIDAuthSchemePop)
                {
                    isPopToken = YES;
                }
            }
            
            NSMutableArray *tokens = _cacheSections[[self rowIdentifier:token.accountIdentifier]];
            [tokens addObject:token];
        }
        
        _cacheSectionTitles = [NSMutableArray arrayWithArray:[_cacheSections allKeys]];
        if (isPopToken)
        {
            MSIDAssymetricKeyPair *keyPair = [self.keyGenerator readKeyPairForAttributes:_keyPairAttributes error:nil];
            if (keyPair)
            {
                NSString *kid = [_popManager generateKidFromModulus:keyPair.keyModulus exponent:keyPair.keyExponent];
                MSALTestAppAsymmetricKey *publicKey = [[MSALTestAppAsymmetricKey alloc] initWithName:self.keyPairAttributes.publicKeyIdentifier kid:kid];
                MSALTestAppAsymmetricKey *privateKey = [[MSALTestAppAsymmetricKey alloc] initWithName:self.keyPairAttributes.privateKeyIdentifier kid:kid];
                _tokenKeys = [[NSMutableArray alloc] initWithObjects:publicKey, privateKey, nil];
                [_cacheSections setObject:_tokenKeys forKey:POP_TOKEN_KEYS];
                [_cacheSectionTitles addObject:POP_TOKEN_KEYS];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_cacheTableView reloadData];
            [self.refreshControl endRefreshing];
        });
    });
}

- (NSString *)rowIdentifier:(MSIDAccountIdentifier *)accountIdentifier
{
    return accountIdentifier.homeAccountId ? accountIdentifier.homeAccountId : accountIdentifier.displayableId;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView
{
    return [_cacheSectionTitles count];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *sectionTitle = [_cacheSectionTitles objectAtIndex:section];
    NSArray *sectionObjects = [_cacheSections objectForKey:sectionTitle];
    return [sectionObjects count];
}

- (UIView *)tableView:(__unused UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *label = [[UILabel alloc] init];
    NSArray *sectionObjects = [_cacheSections objectForKey:[_cacheSectionTitles objectAtIndex:section]];
    if ([sectionObjects count])
    {
        id cacheEntry = [sectionObjects objectAtIndex:0];
        if ([cacheEntry isKindOfClass:[MSIDAccount class]])
        {
            MSIDAccount *account = (MSIDAccount *)cacheEntry;
            label.text = account.username;
        }
        else
        {
            label.text = [_cacheSectionTitles objectAtIndex:section];
        }
    }
    
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor lightGrayColor];
    return label;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(__unused NSInteger)section
{
    return 30;
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cacheCell"];
    
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cacheCell"];
    }
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.font  = [UIFont fontWithName: @"Arial" size: 16.0];
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSString *sectionTitle = [_cacheSectionTitles objectAtIndex:indexPath.section];
    NSArray *sectionObjects = [_cacheSections objectForKey:sectionTitle];
    id cacheEntry = [sectionObjects objectAtIndex:indexPath.row];
    
    if ([cacheEntry isKindOfClass:[MSIDAppMetadataCacheItem class]])
    {
        MSIDAppMetadataCacheItem *appMetadata = [self appMetadataEntries][indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"Client_Id : %@", appMetadata.clientId];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Environment: %@, FamilyId : %@", appMetadata.environment, [appMetadata.familyId length] != 0 ? appMetadata.familyId : @"0"];
        
    }
    else if ([cacheEntry isKindOfClass:[MSIDAccountMetadataCacheItem class]])
    {
        MSIDAccountMetadataCacheItem *accountMetadata = [self accountMetadataEntries][indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"Client_Id : %@", accountMetadata.clientId];
        cell.detailTextLabel.text = @"";
        
    }
    else if ([cacheEntry isKindOfClass:[MSIDBaseToken class]])
    {
        MSIDBaseToken *token = (MSIDBaseToken *)cacheEntry;
        switch (token.credentialType) {
            case MSIDRefreshTokenType:
            {
                MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) token;
                
                if ([token isKindOfClass:[MSIDLegacyRefreshToken class]])
                {
                    cell.textLabel.text = [NSString stringWithFormat:@"Legacy RefreshToken : %@, FRT %@", token.realm, refreshToken.clientId];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id : %@", refreshToken.clientId];
                }
                else
                {
                    cell.textLabel.text = [NSString stringWithFormat:@"RefreshToken : %@, FamilyId : %@", refreshToken.clientId, refreshToken.familyId ? refreshToken.familyId : @"0"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id: %@", refreshToken.clientId];
                }
                
                if ([refreshToken.refreshToken isEqualToString:BAD_REFRESH_TOKEN])
                {
                    cell.textLabel.textColor = [UIColor orangeColor];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id : %@", refreshToken.clientId];
                }
                break;
            }
            case MSIDAccessTokenType:
            {
                MSIDAccessToken *accessToken = (MSIDAccessToken *) token;
                cell.textLabel.text = [NSString stringWithFormat:@"AccessToken [%@] : %@ / %@", @"Bearer", [accessToken.scopes msidToString], accessToken.realm];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id : %@", accessToken.clientId];
                if (accessToken.isExpired)
                {
                    cell.textLabel.textColor = [UIColor redColor];
                }
                break;
            }
            case MSIDIDTokenType:
            {
                cell.textLabel.text = [NSString stringWithFormat:@"Id Token : %@", token.realm];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id : %@", token.clientId];
                break;
            }
            case MSIDLegacySingleResourceTokenType:
            {
                cell.textLabel.text = @"Legacy single resource token";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id : %@", token.clientId];
                break;
            }
            case MSIDAccessTokenWithAuthSchemeType:
            {
                MSIDAccessTokenWithAuthScheme *accessToken = (MSIDAccessTokenWithAuthScheme *) token;
                cell.textLabel.text = [NSString stringWithFormat:@"AccessToken [%@] : %@ / %@",accessToken.tokenType, [accessToken.scopes msidToString], accessToken.realm];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Client_Id : %@, Kid : %@", accessToken.clientId, accessToken.kid];
                if (accessToken.isExpired)
                {
                   cell.textLabel.textColor = [UIColor redColor];
                }
                break;
            }
            default:
                break;
        }
    }
    else if([cacheEntry isKindOfClass:[MSIDAccount class]])
    {
        MSIDAccount *account = (MSIDAccount *)cacheEntry;
        cell.textLabel.text = [NSString stringWithFormat:@"Account : %@", account.environment];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Account Identifier : %@", [self rowIdentifier:account.accountIdentifier]];
    }
    else if([cacheEntry isKindOfClass:[MSALTestAppAsymmetricKey class]])
    {
        MSALTestAppAsymmetricKey *key = (MSALTestAppAsymmetricKey *)cacheEntry;
        cell.textLabel.text = [NSString stringWithFormat:@"Key Identifier : %@", key.name];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Kid : %@", key.kid];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (UISwipeActionsConfiguration *)tableView:(__unused UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(__unused NSIndexPath *)indexPath API_AVAILABLE(ios(11.0))
{
    NSString *sectionTitle = [_cacheSectionTitles objectAtIndex:indexPath.section];
    NSArray *sectionObjects = [_cacheSections objectForKey:sectionTitle];
    id cacheEntry = [sectionObjects objectAtIndex:indexPath.row];
    if ([cacheEntry isKindOfClass:[MSIDAppMetadataCacheItem class]])
    {
        MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)cacheEntry;
        __auto_type deleteTokenAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                title:@"Delete"
                                                                              handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
                                         {
                                             [self deleteAppMetadata:appMetadata];
                                         }];
        
        __auto_type configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteTokenAction]];
        return configuration;
    }
    else if ([cacheEntry isKindOfClass:[MSIDBaseToken class]])
    {
        MSIDBaseToken *token = (MSIDBaseToken *)cacheEntry;
        __auto_type deleteTokenAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                title:@"Delete"
                                                                              handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
                                         {
                                             [self deleteToken:token];
                                         }];
        
        __auto_type invalidateAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:@"Invalidate"
                                                                             handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
                                        {
                                            [self invalidateRefreshToken:(MSIDRefreshToken *)token];
                                        }];
        invalidateAction.backgroundColor = [UIColor orangeColor];
        
        __auto_type expireTokenAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                title:@"Expire"
                                                                              handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
                                         {
                                             [self expireAccessToken:(MSIDAccessToken *)token];
                                         }];
        expireTokenAction.backgroundColor = [UIColor orangeColor];
        
        switch (token.credentialType)
        {
            case MSIDRefreshTokenType:
            {
                if ([token isKindOfClass:[MSIDLegacyRefreshToken class]])
                {
                    return [UISwipeActionsConfiguration configurationWithActions:@[deleteTokenAction]];
                }
                
                return [UISwipeActionsConfiguration configurationWithActions:@[deleteTokenAction, invalidateAction]];
            }
            case MSIDAccessTokenType:
            {
                return [UISwipeActionsConfiguration configurationWithActions:@[deleteTokenAction, expireTokenAction]];
            }
            case MSIDIDTokenType:
            {
                return [UISwipeActionsConfiguration configurationWithActions:@[deleteTokenAction]];
            }
            case MSIDAccessTokenWithAuthSchemeType:
            {
                return [UISwipeActionsConfiguration configurationWithActions:@[deleteTokenAction, expireTokenAction]];
            }
            default:
                return nil;
        }
    }
    else if ([cacheEntry isKindOfClass:[MSIDAccount class]])
    {
        MSIDAccount *account = (MSIDAccount *)cacheEntry;
        __auto_type deleteAccountAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                  title:@"Delete All"
                                                                                handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
                                           {
                                               [self deleteAllEntriesForAccount:account];
                                           }];
        
        __auto_type configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAccountAction]];
        return configuration;
    }
    else if ([cacheEntry isKindOfClass:[MSALTestAppAsymmetricKey class]])
    {
        MSALTestAppAsymmetricKey *key = (MSALTestAppAsymmetricKey *)cacheEntry;
        __auto_type deleteKeyAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                               title:@"Delete"
                                             handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
        {
            [self deleteKey:key];
        }];
        
        __auto_type configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteKeyAction]];
        return configuration;
    }
    else if ([cacheEntry isKindOfClass:[MSIDAccountMetadataCacheItem class]])
    {
        MSIDAccountMetadataCacheItem *accountMetadata = (MSIDAccountMetadataCacheItem *)cacheEntry;
        __auto_type deleteMetadataAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                               title:@"Delete"
                                             handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView, void (__unused ^completionHandler)(BOOL))
        {
            [self deleteAccountMetadata:accountMetadata];
        }];
        
        __auto_type configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteMetadataAction]];
        return configuration;
    }
    
    return nil;
}

#if !TARGET_OS_MACCATALYST
- (nullable NSArray<UITableViewRowAction *> *)tableView:(__unused UITableView *)tableView
                           editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *sectionTitle = [_cacheSectionTitles objectAtIndex:indexPath.section];
    NSArray *sectionObjects = [_cacheSections objectForKey:sectionTitle];
    id cacheEntry = [sectionObjects objectAtIndex:indexPath.row];
    if ([cacheEntry isKindOfClass:[MSIDAppMetadataCacheItem class]])
    {
        MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)cacheEntry;
        UITableViewRowAction *deleteTokenAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Delete"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
         {
             [self deleteAppMetadata:appMetadata];
         }];
        
        return @[deleteTokenAction];
    }
    else if ([cacheEntry isKindOfClass:[MSIDBaseToken class]])
    {
        MSIDBaseToken *token = (MSIDBaseToken *)cacheEntry;
        UITableViewRowAction *deleteTokenAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Delete"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
         {
             [self deleteToken:token];
         }];
        
        UITableViewRowAction* invalidateAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Invalidate"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
         {
             [self invalidateRefreshToken:(MSIDRefreshToken *)token];
         }];
        
        [invalidateAction setBackgroundColor:[UIColor orangeColor]];
        
        UITableViewRowAction* expireTokenAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Expire"
                                         handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
         {
             [self expireAccessToken:(MSIDAccessToken *)token];
         }];
        [expireTokenAction setBackgroundColor:[UIColor orangeColor]];
        
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
            case MSIDAccessTokenWithAuthSchemeType:
            {
               return @[deleteTokenAction, expireTokenAction];
            }
            default:
                return nil;
        }
    }
    else if ([cacheEntry isKindOfClass:[MSIDAccount class]])
    {
        MSIDAccount *account = (MSIDAccount *)cacheEntry;
        return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                    title:@"Delete All"
                                                  handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
                  {
                      [self deleteAllEntriesForAccount:account];
                  }]];
    }
    else if ([cacheEntry isKindOfClass:[MSALTestAppAsymmetricKey class]])
    {
        MSALTestAppAsymmetricKey *key = (MSALTestAppAsymmetricKey *)cacheEntry;
        return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                    title:@"Delete"
                                                  handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
                  {
                      [self deleteKey:key];
                  }]];
    }
    
    else if ([cacheEntry isKindOfClass:[MSIDAccountMetadataCacheItem class]])
    {
        MSIDAccountMetadataCacheItem *accountMetadata = (MSIDAccountMetadataCacheItem *)cacheEntry;
        return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                    title:@"Delete"
                                                  handler:^(__unused UITableViewRowAction * _Nonnull action, __unused NSIndexPath * _Nonnull indexPath)
                  {
                      [self deleteAccountMetadata:accountMetadata];
                  }]];
    }
    
    return nil;
}
#endif

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // All tasks are handled by blocks defined in editActionsForRowAtIndexPath, however iOS8 requires this method to enable editing
    (void)tableView;
    (void)editingStyle;
    (void)indexPath;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *sectionTitle = [_cacheSectionTitles objectAtIndex:indexPath.section];
    NSArray *sectionObjects = [_cacheSections objectForKey:sectionTitle];
    id cacheEntry = [sectionObjects objectAtIndex:indexPath.row];
    MSALCacheItemDetailViewController *vc = [[MSALCacheItemDetailViewController alloc] init];
    vc.cacheItem = cacheEntry;
    [[self navigationController] pushViewController:vc animated:YES];
}

@end
