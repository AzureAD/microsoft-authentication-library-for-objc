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

#import "MSALB2CAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDB2CAuthority.h"
#import "MSIDAuthority+Internal.h"

@implementation MSALB2CAuthority

- (instancetype)initWithURL:(NSURL *)url
                      error:(NSError **)error
{
    return [self initWithURL:url validateFormat:NO error:error];
}

- (instancetype)initWithURL:(NSURL *)url
             validateFormat:(BOOL)validateFormat
                      error:(NSError **)error
{
    self = [super initWithURL:url error:error];
    if (self)
    {
        self.msidAuthority = [[MSIDB2CAuthority alloc] initWithURL:url validateFormat:validateFormat context:nil  error:error];
        if (!self.msidAuthority) return nil;
    }
    
    return self;
}

- (NSURL *)url
{
    return self.msidAuthority.url;
}

@end
