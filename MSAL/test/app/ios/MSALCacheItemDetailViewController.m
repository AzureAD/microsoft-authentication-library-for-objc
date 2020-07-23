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
#import "MSIDJsonSerializable.h"

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
        
        if ([self.cacheItem respondsToSelector:@selector(jsonDictionary)])
        {
            jsonDict = [self.cacheItem jsonDictionary];
        }
        if ([self.cacheItem respondsToSelector:@selector(tokenCacheItem)])
        {
            id tokenCacheItem = [self.cacheItem tokenCacheItem];
            if ([tokenCacheItem respondsToSelector:@selector(jsonDictionary)])
            {
                jsonDict = [tokenCacheItem jsonDictionary];
            }
        }
        else if([self.cacheItem isKindOfClass:[MSALTestAppAsymmetricKey class]])
        {
            MSALTestAppAsymmetricKey *key = (MSALTestAppAsymmetricKey *)self.cacheItem;
            NSMutableDictionary *keyDict = [NSMutableDictionary new];
            [keyDict setObject:key.kid forKey:@"kid"];
            [keyDict setObject:key.name forKey:@"label"];
            jsonDict = keyDict;
        }
        
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:&error];
        if ([jsonData length] > 0)
        {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                         encoding:NSUTF8StringEncoding];
            _cacheItemView.text = jsonString;
        }
        else
        {
            _cacheItemView.text = [NSString stringWithFormat:@"An error happened : %@", error];
        }
    }
}

@end
