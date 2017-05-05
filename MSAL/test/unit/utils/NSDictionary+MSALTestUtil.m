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

#import "NSDictionary+MSALTestUtil.h"

@implementation NSDictionary (MSALTestUtil)

- (BOOL)compareToActual:(NSDictionary *)dictionary
{
    BOOL fSame = YES;
    
    for (NSString *key in self)
    {
        id myVal = self[key];
        id otherVal = dictionary[key];
        if (!otherVal)
        {
            NSLog(@"\"%@\" missing from result dictionary.", key);
            fSame = NO;
        }
        else if (![myVal isKindOfClass:[MSALTestSentinel class]] && ![myVal isEqual:otherVal])
        {
            NSLog(@"\"%@\" does not match. Expected: \"%@\" Actual: \"%@\"", key, self[key], otherVal);
            fSame = NO;
        }
    }
    
    for (NSString *key in dictionary)
    {
        if (!self[key])
        {
            NSLog(@"Extra key \"%@\" in result dictionary: \"%@\"", key, dictionary[key]);
            fSame = NO;
        }
    }
    
    return fSame;
}

- (NSString *)base64UrlJson
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
    return [NSString msalBase64UrlEncodeData:jsonData];
}

@end

@implementation MSALTestSentinel

static MSALTestSentinel *s_sentinel = nil;

+ (void)initialize
{
    s_sentinel = [MSALTestSentinel new];
}

+ (instancetype)sentinel
{
    return s_sentinel;
}

@end
