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

#import "MSALAuthorityFactory.h"
#import "MSALAADAuthority.h"
#import "MSIDAADAuthority.h"
#import "MSALB2CAuthority.h"
#import "MSIDB2CAuthority.h"
#import "MSALADFSAuthority.h"
#import "MSIDADFSAuthority.h"
#import "MSALB2CAuthority_Internal.h"

@implementation MSALAuthorityFactory

+ (MSALAuthority *)authorityFromUrl:(NSURL *)url
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    return [self authorityFromUrl:url validateFormat:YES rawTenant:nil context:context error:error];
}

+ (MSALAuthority *)authorityFromUrl:(NSURL *)url
                     validateFormat:(BOOL)validateFormat
                          rawTenant:(NSString *)rawTenant
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    if ([MSIDB2CAuthority isAuthorityFormatValid:url context:context error:nil])
    {
        __auto_type b2cAuthority = [[MSALB2CAuthority alloc] initWithURL:url validateFormat:validateFormat error:nil];
        if (b2cAuthority) return b2cAuthority;
    }
    
    if ([MSIDADFSAuthority isAuthorityFormatValid:url context:context error:nil])
    {
        __auto_type adfsAuthority = [[MSALADFSAuthority alloc] initWithURL:url error:nil];
        if (adfsAuthority) return adfsAuthority;
    }
    
    if ([MSIDAADAuthority isAuthorityFormatValid:url context:context error:nil])
    {
        __auto_type aadAuthority = [[MSALAADAuthority alloc] initWithURL:url rawTenant:rawTenant error:nil];
        if (aadAuthority) return aadAuthority;
    }
    
    MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, @"Provided authority url is not a valid authority.", nil);
    
    return nil;
}

@end
