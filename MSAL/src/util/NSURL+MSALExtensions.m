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

#import "NSURL+MSALExtensions.h"
#import "MSALAuthority.h"
#import "MSALTelemetryEventStrings.h"

@implementation NSURL (MSAL)

- (NSString *)msalHostWithPort
{
    if (!self.host)
    {
        return @"";
    }
    
    if (self.port == nil || self.port.intValue == 443)
    {
        return self.host;
    }
    else
    {
        return [NSString stringWithFormat:@"%@:%@", self.host, self.port];
    }
}

- (NSString *)scrubbedHttpPath
{
    if ([self.pathComponents count] < 2 || // Full URL wasn't provided
        [MSALAuthority isTenantless:self]) // We don't scrub the default tenant
    {
        return [self absoluteString];
    }
    
    NSString *firstPathComponent = self.pathComponents[1].lowercaseString;
    NSString *tenant = nil;
    
    if ([firstPathComponent isEqualToString:@"tfp"])
    {
        if ([self.pathComponents count] > 2)
        {
            tenant = self.pathComponents[2].lowercaseString;
        }
        else
        {
            // It's a malformed URL, log minimum information to not reveal PII accidentally
            return [NSString stringWithFormat:@"%@://%@/%@", self.scheme, [self msalHostWithPort], firstPathComponent];
        }
    }
    else
    {
        tenant = firstPathComponent;
    }
    
    return [[self absoluteString] stringByReplacingOccurrencesOfString:tenant withString:MSAL_TELEMETRY_KEY_TENANT_SCRUBBED_VALUE];
}

@end
