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

#import <Foundation/Foundation.h>

@interface NSString (MSALHelperMethods)

/*! Encodes string to the Base64 encoding. */
- (NSString *)msalBase64UrlEncode;
/*! Decodes string from the Base64 encoding. */
- (NSString *)msalBase64UrlDecode;

/*! Converts NSData to base64 String */
+ (NSString *)msalBase64UrlEncodeData:(NSData *)data;
/*! Converts base64 String to NSData */
+ (NSData *)msalBase64UrlDecodeData:(NSString *)encodedString;

/*! Returns YES if the string is nil, or contains only white space */
+ (BOOL)msalIsStringNilOrBlank:(NSString *)string;

/*! Returns the same string, but without the leading and trailing whitespace */
- (NSString *)msalTrimmedString;

/*! Decodes a previously URL encoded string. */
- (NSString *)msalUrlFormDecode;

/*! Encodes the string to pass it as a URL agrument. */
- (NSString *)msalUrlFormEncode;

/*! Computes a SHA256 hash of the string in hex string */
- (NSString *)msalComputeSHA256Hex;

/*! Shorter hex string for friendlier logs */
- (NSString *)msalShortSHA256Hex;

/*! Generate a URL-safe string of random data */
+ (NSString *)randomUrlSafeStringOfSize:(NSUInteger)size;

@end
