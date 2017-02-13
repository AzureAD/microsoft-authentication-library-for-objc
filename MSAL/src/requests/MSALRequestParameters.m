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

#import "MSALRequestParameters.h"
#import "MSALUIBehavior.h"
#import "MSALError_Internal.h"

@implementation MSALRequestParameters

- (void)setScopesFromArray:(NSArray<NSString *> *)array
{
    self.scopes = [[NSOrderedSet alloc] initWithArray:array copyItems:YES];
}

- (BOOL)setRedirectUri:(NSString *)string
                 error:(NSError * __autoreleasing *)error
{
    self.redirectUri = [NSURL URLWithString:string];
    CHECK_ERROR_RETURN_NIL(self.redirectUri, self, MSALErrorInvalidParameter, @"redirectUri is not a valid URI");
    
    return YES;
}

- (BOOL)validateParameters:(NSError * __autoreleasing *)error
{
    (void)error;
    @throw @"TODO";
    return false;
}

@end
