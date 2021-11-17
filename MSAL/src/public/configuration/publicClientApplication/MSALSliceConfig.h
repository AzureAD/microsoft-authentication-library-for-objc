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

NS_ASSUME_NONNULL_BEGIN

/**
    MSAL configuration interface responsible for custom parameters  to target MSAL at a specific test slice & flight
*/
@interface MSALSliceConfig : NSObject <NSCopying>

#pragma mark - Configuration options

/**
   Specific test slice
 */
@property (atomic) NSString *slice;

/**
  Specific data center
*/
@property (atomic) NSString *dc;

/**
  Current slice and flight configuration
*/
@property (readonly) NSDictionary *sliceDictionary;

#pragma mark - Constructing MSALSliceConfig

/**
    Initializes MSALSliceConfig with specified slice and dc parameters
    @param slice Specific test slice
    @param dc Specific data center
 */
- (nullable instancetype)initWithSlice:(nullable NSString *)slice dc:(nullable NSString *)dc NS_DESIGNATED_INITIALIZER;

/**
    Initializes MSALSliceConfig with specified slice and dc parameters
    @param slice Specific test slice
    @param dc Specific data center
*/
+ (nullable instancetype)configWithSlice:(nullable NSString *)slice dc:(nullable NSString *)dc;

#pragma mark - Unavailable initializers

/**
    Use `[MSALSliceConfig initWithSlice:dc:]` instead
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
   Use `[MSALSliceConfig initWithSlice:dc:]` instead
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
