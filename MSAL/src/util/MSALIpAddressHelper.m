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

#import "MSALIpAddressHelper.h"

#import <ifaddrs.h>
#import <arpa/inet.h>

@implementation MSALIpAddressHelper

+ (NSString *)msalDeviceIpAddress
{
    NSString *ip = nil;
    
    struct ifaddrs * address = NULL;
    struct ifaddrs * addressCopy = NULL;
    
    int success = getifaddrs(&address);
    
    if (success == 0)
    {
        addressCopy = address;
        
        while(addressCopy != NULL)
        {
            if(addressCopy->ifa_addr->sa_family == AF_INET)
            {
                if([[NSString stringWithUTF8String:addressCopy->ifa_name] isEqualToString:@"en0"])
                {
                    ip = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addressCopy->ifa_addr)->sin_addr)];
                    
                    // mask last octet in the ip address with xxx
                    NSInteger length = [[ip pathExtension] length];
                    ip = [ip stringByDeletingPathExtension];
                    NSString *mark = [@"" stringByPaddingToLength:length withString:@"x" startingAtIndex:0];
                    ip = [ip stringByAppendingPathExtension:mark];
                    
                    break;
                }
            }
            addressCopy = addressCopy->ifa_next;
        }
    }
    
    freeifaddrs(address);
    
    return ip;
}

@end
