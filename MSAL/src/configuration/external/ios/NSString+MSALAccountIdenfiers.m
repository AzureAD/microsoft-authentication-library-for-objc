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
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to parse unsigned long long from a string, length: %d", stringLen);
        return nil;
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:self];
    unsigned long long ull;
    if (![scanner scanHexLongLong:&ull])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to parse unsigned long long from a string.");
        return nil;
    }
    
    return [self dataFromUInt64:ull];
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

#pragma mark - Private

- (NSData *)dataFromUInt64:(NSUInteger)value
{
    const int length = 16;
    const int lastIndex = length - 1;
    const int bitsInByte = 8;
    char buffer[length];
    
    for (int idx = 0; idx < length; ++idx)
    {
        buffer[idx] = '\0';
    }
    
    for (int idx = 0; idx < length; ++idx)
    {
        buffer[lastIndex - idx] = (value & 0xff);
        // Shift to next byte.
        value = value >> bitsInByte;
    }
    
    return [[NSMutableData alloc] initWithBytes:buffer length:length];
}

@end
