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

#import <Foundation/Foundation.h>

#import "NSDictionary+MSALExtensions.h"
#import "NSString+MSALHelperMethods.h"

@implementation NSDictionary (MSAL)

// Decodes a www-form-urlencoded string into a dictionary of key/value pairs.
// Always returns a dictionary, even if the string is nil, empty or contains no pairs
+ (NSDictionary *)msalURLFormDecode:(NSString *)string
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    
    if (string && string.length != 0)
    {
        NSArray *pairs = [string componentsSeparatedByString:@"&"];
        
        for (NSString *pair in pairs)
        {
            NSArray *elements = [pair componentsSeparatedByString:@"="];
            
            if (elements && elements.count == 2)
            {
                NSString *key     = [[[elements objectAtIndex:0] msalTrimmedString] msalUrlFormDecode];
                NSString *value   = [[[elements objectAtIndex:1] msalTrimmedString] msalUrlFormDecode];
                if (key && key.length != 0)
                    [parameters setObject:value forKey:key];
            }
        }
    }
    return parameters;
}

// Encodes a dictionary consisting of a set of name/values pairs that are strings to www-form-urlencoded
// Returns nil if the dictionary is empty, otherwise the encoded value
- (NSString *)msalURLFormEncode
{
    __block NSMutableString *parameters = nil;
    
    [self enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL *stop)
     {
         (void)stop;
         NSString *encodedKey = [[((NSString *)key) msalTrimmedString] msalUrlFormEncode];
         NSString *encodedValue = [[((NSString *)value) msalTrimmedString] msalUrlFormEncode];
         
         if (parameters == nil)
         {
             parameters = [NSMutableString new];
             [parameters appendFormat:@"%@=%@", encodedKey, encodedValue];
         }
         else
         {
             [parameters appendFormat:@"&%@=%@", encodedKey, encodedValue];
         }
     }];
    return parameters;
}

@end
