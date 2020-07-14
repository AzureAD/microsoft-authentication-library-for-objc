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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import "MSALCacheItemDetailViewController.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDAccessToken.h"
#import "MSIDIdToken.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAccount.h"
#import "MSIDRefreshToken.h"
#import "MSALTestAppAsymmetricKey.h"
#import "MSIDAccountMetadataCacheItem.h"

@interface MSALCacheItemDetailViewController ()


@end

@implementation MSALCacheItemDetailViewController
{
    UITextView *_cacheItemView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setUpDetailView];
    
    // Do any additional setup after loading the view.
}

- (void)setUpDetailView
{
    if (self.cacheItem)
    {
        _cacheItemView = [[UITextView alloc] initWithFrame:self.view.bounds];
        _cacheItemView.font = [UIFont systemFontOfSize:16.0f];
        [self.view addSubview:_cacheItemView];
        NSDictionary *jsonDict = [NSDictionary new];
        
        if ([self.cacheItem isKindOfClass:[MSIDBaseToken class]])
        {
            MSIDBaseToken *token = (MSIDBaseToken *)self.cacheItem;
            MSIDCredentialCacheItem *item = token.tokenCacheItem;
            jsonDict = item.jsonDictionary;
        }
        else if ([self.cacheItem isKindOfClass:[MSIDAppMetadataCacheItem class]])
        {
            MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)self.cacheItem;
            jsonDict = appMetadata.jsonDictionary;
            
        }
        else if([self.cacheItem isKindOfClass:[MSIDAccount class]])
        {
            MSIDAccount *account = (MSIDAccount *)self.cacheItem;
            jsonDict = account.jsonDictionary;
        }
        else if([self.cacheItem isKindOfClass:[MSALTestAppAsymmetricKey class]])
        {
            MSALTestAppAsymmetricKey *key = (MSALTestAppAsymmetricKey *)self.cacheItem;
            NSMutableDictionary *keyDict = [NSMutableDictionary new];
            [keyDict setObject:key.kid forKey:@"kid"];
            [keyDict setObject:key.name forKey:@"label"];
            jsonDict = keyDict;
        }
        else if([self.cacheItem isKindOfClass:[MSIDAccountMetadataCacheItem class]])
        {
            MSIDAccountMetadataCacheItem *accountMetadata = (MSIDAccountMetadataCacheItem *)self.cacheItem;
            jsonDict = accountMetadata.jsonDictionary;
        }
        
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:&error];
        if ([jsonData length] > 0)
        {
            NSLog(@"Successfully serialized the dictionary into data = %@", jsonData);
            NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                         encoding:NSUTF8StringEncoding];
            NSLog(@"JSON String = %@", jsonString);
            _cacheItemView.text = jsonString;
        }
        else
        {
            NSLog(@"An error happened = %@", error);
        }
    }
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
