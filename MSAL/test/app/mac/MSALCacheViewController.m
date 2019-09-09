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
#import "MSIDMacCredentialStorageItem.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccessToken.h"
#import "MSIDIdToken.h"
#import "MSIDKeychainTokenCache.h"

static NSString *s_appMetadata = @"App-Metadata";
static NSString *s_badRefreshToken = @"Bad-Refresh-Token";

@interface MSALCacheViewController ()

@property (weak) IBOutlet NSOutlineView *outLineView;
@property (nonatomic) MSIDAccountCredentialCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *legacyAccessor;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (strong) NSArray *accounts;
@property (strong) NSArray *appMetadataEntries;
@property (strong) NSMutableDictionary *cacheDict;

@end

@implementation MSALCacheViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.outLineView.delegate = self;
    self.outLineView.dataSource = self;
    [self loadCache];
    // Do view setup here.
}

#pragma mark Helper Methods

- (void)loadCache
{
    id<MSIDExtendedTokenCacheDataSource> dataSource = nil;
    NSArray *otherAccessors = nil;
    
    if (@available(macOS 10.15, *))
    {
        dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDMacKeychainTokenCache.defaultKeychainGroup error:nil];
        
        id<MSIDExtendedTokenCacheDataSource> secondaryDataSource = MSIDMacKeychainTokenCache.defaultKeychainCache;
        
        if (secondaryDataSource)
        {
            self.legacyAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:secondaryDataSource otherCacheAccessors:nil];
            if (self.legacyAccessor) otherAccessors = @[self.legacyAccessor];
        }
    }
    else
    {
        dataSource = MSIDMacKeychainTokenCache.defaultKeychainCache;
    }
    
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:otherAccessors];
    self.tokenCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDMacKeychainTokenCache.defaultKeychainCache];
    
    self.cacheDict = [NSMutableDictionary dictionary];
    
    self.accounts = [self.defaultAccessor accountsWithAuthority:nil
                                                       clientId:nil
                                                       familyId:nil
                                              accountIdentifier:nil
                                                        context:nil
                                                          error:nil];
    
    self.appMetadataEntries = [self.defaultAccessor getAppMetadataEntries:nil context:nil error:nil];
    
    if ([[self appMetadataEntries] count])
    {
        [self.cacheDict setObject:[self appMetadataEntries] forKey:s_appMetadata];
    }
    
    for (MSIDAccount *account in [self accounts])
    {
        self.cacheDict[[self accountIdentifier:account.accountIdentifier]] = [NSMutableArray array];
        [self.cacheDict[[self accountIdentifier:account.accountIdentifier]] addObject:account];
    }
    
    NSMutableArray *allTokens = [[self.defaultAccessor allTokensWithContext:nil error:nil] mutableCopy];
    [allTokens addObjectsFromArray:[self.legacyAccessor allTokensWithContext:nil error:nil]];
    
    for (MSIDBaseToken *token in allTokens)
    {
        NSMutableArray *tokens = self.cacheDict[[self accountIdentifier:token.accountIdentifier]];
        [tokens addObject:token];
    }
    
    [self.outLineView reloadData];
}

- (NSString *)getUPN:(NSString *)accountIdentifier
{
    for (MSIDAccount *account in self.accounts)
    {
        if ([account.accountIdentifier.homeAccountId isEqualToString:accountIdentifier])
        {
            return account.username;
        }
    }
    
    return nil;
}

- (NSString *)accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
{
    return accountIdentifier.homeAccountId ? accountIdentifier.homeAccountId : accountIdentifier.displayableId;
}

- (void)invalidateRefreshToken:(MSIDRefreshToken *)refreshToken
{
    if (refreshToken)
    {
        refreshToken.refreshToken = s_badRefreshToken;
        [self.tokenCache saveCredential:refreshToken.tokenCacheItem context:nil error:nil];
        [self loadCache];
    }
}

- (void)expireAccessToken:(MSIDAccessToken *)accessToken
{
    if (accessToken)
    {
        accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];
        [self.tokenCache saveCredential:accessToken.tokenCacheItem context:nil error:nil];
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
        
        [self loadCache];
    }
}

- (void)deleteAppMetadata:(MSIDAppMetadataCacheItem *)appMetadata
{
    if (appMetadata)
    {
        [self.tokenCache removeAppMetadata:appMetadata context:nil error:nil];
        [self loadCache];
    }
}

- (void)deleteToken:(MSIDBaseToken *)token
{
    if (token)
    {
        switch (token.credentialType)
        {
            case MSIDRefreshTokenType:
            {
                [self.defaultAccessor validateAndRemoveRefreshToken:(MSIDRefreshToken *)token
                                                            context:nil
                                                              error:nil];
                break;
            }
            default:
                [self.defaultAccessor removeToken:token context:nil error:nil];
                break;
        }
        
        [self loadCache];
    }
}

#pragma mark Button Actions

- (IBAction)refreshCache:(id)sender
{
    [self loadCache];
}


- (IBAction)expireOrInvalidateToken:(id)sender
{
    id item = [self.outLineView itemAtRow:[self.outLineView selectedRow]];
    
    if ([item isKindOfClass:[MSIDBaseToken class]])
    {
        if ([item isKindOfClass:[MSIDRefreshToken class]])
        {
            [self invalidateRefreshToken:(MSIDRefreshToken *)item];
        }
        else if([item isKindOfClass:[MSIDAccessToken class]])
        {
            [self expireAccessToken:(MSIDAccessToken *)item];
        }
    }
}

- (IBAction)deleteItem:(id)sender
{
    id item = [self.outLineView itemAtRow:[self.outLineView selectedRow]];
    if ([item isKindOfClass:[MSIDAccount class]])
    {
        [self deleteAllEntriesForAccount:(MSIDAccount *)item];
    }
    else if ([item isKindOfClass:[MSIDBaseToken class]])
    {
        [self deleteToken:(MSIDBaseToken *)item];
    }
    else if ([item isKindOfClass:[MSIDAppMetadataCacheItem class]])
    {
        [self deleteAppMetadata:(MSIDAppMetadataCacheItem *)item];
    }
}

#pragma mark NSOutlineView Data Source Test Methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return item ? [[self.cacheDict objectForKey:item] count] : [[self.cacheDict allKeys] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return item ? [[self.cacheDict objectForKey:item] count] : YES;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    return item ? [[self.cacheDict objectForKey:item] objectAtIndex:index] : [[self.cacheDict allKeys] objectAtIndex:index];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"cacheColumn"])
    {
        NSString *textValue;
        NSTableCellView *cellView = [outlineView makeViewWithIdentifier:@"cacheCell" owner:self];
        
        id parent = [outlineView parentForItem:item];
        if (!parent)
        {
            textValue = [self getUPN:item] ? [self getUPN:item] : s_appMetadata;
        }
        else if ([item isKindOfClass:[MSIDAccount class]])
        {
            MSIDAccount *account = (MSIDAccount *)item;
            textValue = [NSString stringWithFormat:@"Account: AccountIdentifier - %@", [self accountIdentifier:account.accountIdentifier]];
        }
        else if ([item isKindOfClass:[MSIDAppMetadataCacheItem class]])
        {
            MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)item;
            textValue = [NSString stringWithFormat:@"AppMetadata: ClientId - %@, Environment - %@, FamilyId - %@", appMetadata.clientId, appMetadata.environment, appMetadata.familyId];
            
        }
        else if ([item isKindOfClass:[MSIDBaseToken class]])
        {
            MSIDBaseToken *token = (MSIDBaseToken *)item;
            switch (token.credentialType)
            {
                case MSIDRefreshTokenType:
                {
                    MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) token;
                    textValue = [NSString stringWithFormat:@"Refresh Token: ClientId - %@, Realm - %@, FamilyId - %@", refreshToken.clientId, refreshToken.realm, refreshToken.familyId];
                    
                    if ([refreshToken.refreshToken isEqualToString:s_badRefreshToken])
                    {
                        cellView.textField.textColor = [NSColor redColor];
                        [cellView.textField setStringValue:textValue];
                        return cellView;
                    }
                    
                    break;
                }
                case MSIDAccessTokenType:
                {
                    MSIDAccessToken *accessToken = (MSIDAccessToken *) token;
                    textValue = [NSString stringWithFormat:@"AccessToken: ClientId - %@, Scopes - %@, Realm - %@", accessToken.clientId, [accessToken.scopes msidToString],accessToken.realm];
                    
                    if (accessToken.isExpired)
                    {
                        cellView.textField.textColor = [NSColor redColor];
                        [cellView.textField setStringValue:textValue];
                        return cellView;
                    }
                    
                    break;
                }
                case MSIDIDTokenType:
                {
                    textValue = [NSString stringWithFormat:@"IdToken: ClientId - %@, Realm - %@", token.clientId, token.realm];
                    break;
                }
                default:
                    break;
            }
        }
        
        [cellView.textField setTextColor:NSColor.blackColor];
        [cellView.textField setStringValue:textValue];
        return cellView;
    }
    
    return nil;
}

@end
