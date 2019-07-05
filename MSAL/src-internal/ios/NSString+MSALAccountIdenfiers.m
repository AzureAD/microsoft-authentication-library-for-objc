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
#import "NSString+MSIDExtensions.h"

@implementation NSString (MSALAccountIdenfiers)

- (NSString *)msalStringAsGUID
{
    if (self.length != 16)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unexpected string lenght");
        return nil;
    }
    
    NSData *guidData = [self msalStringAsGUIDData];
    
    if (!guidData)
    {
        return nil;
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:[guidData bytes]];
    return uuid.UUIDString.lowercaseString;
}

- (NSData *)msalStringAsGUIDData
{
    int stringLen = (int)[self length];
    
    if (stringLen > 16)
    {
        return nil;
    }
    
    NSUInteger zeroFillLen = (16 - (stringLen + 1) / 2);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:16];
    
    char chars[3] = {'\0','\0','\0'};
    
    for (int i = stringLen-1; i >= 0; i-=2)
    {
        unsigned char firstChar = '0';
        
        if (i - 1 >= 0)
        {
            firstChar = [self characterAtIndex:i-1];
        }
        
        unsigned char secondChar = [self characterAtIndex:i];
        
        chars[0] = firstChar;
        chars[1] = secondChar;
        unsigned char resultChar = strtol(chars, NULL, 16);
        
        [result replaceBytesInRange:NSMakeRange(zeroFillLen+i/2, 1) withBytes:&resultChar];
    }
    
    return result;
}

- (NSString *)msalGUIDAsShortString
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self];
    
    if (!uuid)
    {
        return nil;
    }
    
    uuid_t uuidBytes;
    [uuid getUUIDBytes:uuidBytes];
    
    NSUInteger dataLength = 16;
    NSMutableString *result = [NSMutableString stringWithCapacity:dataLength*2];
    
    BOOL ignoreLeadingZeroes = YES;
    for (NSUInteger i = 0; i < dataLength; i++)
    {
        if (!ignoreLeadingZeroes || uuidBytes[i] != 0)
        {
            NSString *format = ignoreLeadingZeroes ? @"%x" : @"%02x";
            [result appendFormat:format, uuidBytes[i]];
        }
        
        if (uuidBytes[i] != 0)
        {
            ignoreLeadingZeroes = NO;
        }
    }
    
    return result;
}

@end
