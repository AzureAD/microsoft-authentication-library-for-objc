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

#import "MSALLogger.h"

@implementation MSALLogger
{
    MSALLogCallback _callback;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // The default log level should be info, anything more restrictive then this
    // and we'll probably not have enough diagnostic information, however verbose
    // will most likely be too noisy for most usage.
    self.level = MSALLogLevelInfo;
    
    return self;
}

+ (MSALLogger *)sharedLogger
{
    static dispatch_once_t once;
    static MSALLogger * s_logger;
    
    dispatch_once(&once, ^{
        s_logger = [MSALLogger new];
    });
    
    return s_logger;
}

- (void)setCallback:(MSALLogCallback)callback
{
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        self->_callback = callback;
    });
}

@end
