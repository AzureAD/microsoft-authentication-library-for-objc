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

#import "MSALJsonObject.h"

@implementation MSALJsonObject

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _json = [NSMutableDictionary new];
    
    return self;
}

- (id)initWithData:(NSData *)data
             error:(NSError * __autoreleasing *)error
{
    CHECK_ERROR_RETURN_NIL(data, nil, MSALErrorInternal, @"Attempt to initialize JSON object (%@) with nil data", NSStringFromClass(self.class));
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _json = [NSJSONSerialization JSONObjectWithData:data
                                            options:NSJSONReadingMutableContainers
                                              error:error];
    
    if (!_json)
    {
        return nil;
    }
    
    return self;
}

- (NSData *)serialize:(NSError * __autoreleasing *)error
{
    return [NSJSONSerialization dataWithJSONObject:_json
                                           options:0
                                             error:error];
}

- (id)initWithJson:(NSDictionary *)json
             error:(NSError * __autoreleasing *)error
{
    CHECK_ERROR_RETURN_NIL(json, nil, MSALErrorInternal, @"Attempt to initialize JSON object with nil data");
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _json = [json mutableCopy];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    return _json;
}

@end
