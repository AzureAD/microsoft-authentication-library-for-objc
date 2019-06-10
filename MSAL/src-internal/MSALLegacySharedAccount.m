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

#import "MSALLegacySharedAccount.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"

@interface MSALLegacySharedAccount()

@property (nonatomic, readwrite) NSDictionary *jsonDictionary;

@end

@implementation MSALLegacySharedAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _jsonDictionary = jsonDictionary;
        _accountType = [jsonDictionary msidStringObjectForKey:@"type"];
        _accountIdentifier = [jsonDictionary msidStringObjectForKey:@"id"];
        
        if ([NSString msidIsStringNilOrBlank:_accountType]
            || [NSString msidIsStringNilOrBlank:_accountIdentifier])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected shared account found without type or identifier", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _signinStatusDictionary = [jsonDictionary msidObjectForKey:@"signInStatus" ofClass:[NSDictionary class]];
    }
    
    return self;
}

#pragma mark - Match

- (BOOL)matchesParameters:(MSALAccountEnumerationParameters *)parameters
{
    return YES;
}

@end
