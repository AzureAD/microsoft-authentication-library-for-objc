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

#import "NSString+MSALAccountIdenfiers.h"

@implementation NSString (MSALAccountIdenfiers)

- (NSString *)msalStringAsGUID
{
    if (self.length != 16)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unexpected string lenght");
        return nil;
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:[[self msalStringAsGUIDData] bytes]];
    return uuid.UUIDString.lowercaseString;
}

- (NSData *)msalStringAsGUIDData
{
    NSMutableData *result = [[NSMutableData alloc] initWithLength:16];
    unsigned char b;
    char chars[3] = {'\0','\0','\0'};
    for (int i=0; i < [self length]/2; i++)
    {
        chars[0] = [self characterAtIndex:i*2];
        chars[1] = [self characterAtIndex:i*2+1];
        b = strtol(chars, NULL, 16);
        
        if ([result length] > 8+i)
        {
            [result replaceBytesInRange:NSMakeRange(8+i, 1) withBytes:&b length:1];
        }
    }
    
    return result;
}

@end
