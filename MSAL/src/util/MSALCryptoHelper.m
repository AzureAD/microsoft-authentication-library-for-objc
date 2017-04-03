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

#import "MSALCryptoHelper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MSALCryptoHelper

+ (NSData *)msalSHA256fromString:(NSString *)string;
{
    NSData *inputData = [string dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *outData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    
    // input length shouldn't be this big
    THROW_ON_CONDITION_ARGUMENT(inputData.length > UINT32_MAX, string(length too big));
    
    CC_SHA256(inputData.bytes, (uint32_t)inputData.length, outData.mutableBytes);
    
    return outData;
}

@end
