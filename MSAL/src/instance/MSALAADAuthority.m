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

#import "MSALAADAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAADAuthority.h"
#import "MSALErrorConverter.h"
#import "NSURL+MSIDAADUtils.h"

@implementation MSALAADAuthority

- (instancetype)initWithURL:(NSURL *)url
                      error:(NSError **)error
{
    return [self initWithURL:url rawTenant:nil error:error];
}

- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                           rawTenant:(NSString *)rawTenant
                               error:(NSError **)error
{
    self = [super initWithURL:url error:error];
    if (self)
    {
        self.msidAuthority = [[MSIDAADAuthority alloc] initWithURL:url rawTenant:rawTenant context:nil error:error];
        if (!self.msidAuthority) return nil;
    }
    
    return self;
}

- (instancetype)initWithCloudInstance:(MSALAzureCloudInstance)cloudInstance
                         audienceType:(MSALAudienceType)audienceType
                            rawTenant:(NSString *)rawTenant
                                error:(NSError **)error
{
    NSString *environment = [self environmentFromCloudInstance:cloudInstance];
    
    if (!environment)
    {
        if (error)
        {
            NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Invalid MSALAzureCloudInstance provided", nil, nil, nil, nil, nil);
            *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        }
        
        return nil;
    }
    
    return [self initWithEnvironment:environment
                        audienceType:audienceType
                           rawTenant:rawTenant
                               error:error];
}

- (instancetype)initWithEnvironment:(NSString *)environment
                       audienceType:(MSALAudienceType)audienceType
                          rawTenant:(NSString *)rawTenant
                              error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:environment])
    {
        if (error)
        {
            NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Invalid environment provided", nil, nil, nil, nil, nil);
            *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        }
        
        return nil;
    }
    
    if (![NSString msidIsStringNilOrBlank:rawTenant])
    {
        if (audienceType != MSALAzureADMyOrgOnlyAudience)
        {
            if (error)
            {
                NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Invalid MSALAudienceType provided. You can only provide rawTenant when using MSALAzureADMyOrgOnlyAudience.", nil, nil, nil, nil, nil);
                *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
            }
            
            return nil;
        }
        
        NSURL *aadURL = [NSURL msidAADURLWithEnvironment:environment tenant:rawTenant];
        return [self initWithURL:aadURL rawTenant:nil error:error];
    }
    
    NSString *audienceString = [self audienceFromType:audienceType error:error];
    
    if (!audienceString)
    {
        return nil;
    }
    
    NSURL *aadURL = [NSURL msidAADURLWithEnvironment:environment tenant:audienceString];
    return [self initWithURL:aadURL rawTenant:nil error:error];
}

// https://docs.microsoft.com/en-us/azure/active-directory/develop/authentication-national-cloud#azure-ad-authentication-endpoints
- (NSString *)environmentFromCloudInstance:(MSALAzureCloudInstance)cloudInstance
{
    switch (cloudInstance) {
        case MSALAzurePublicCloudInstance:
            return @"login.microsoftonline.com";
        case MSALAzureChinaCloudInstance:
            return @"login.chinacloudapi.cn";
        case MSALAzureGermanyCloudInstance:
            return @"login.microsoftonline.de";
        case MSALAzureUsGovernmentCloudInstance:
            return @"login.microsoftonline.us";
            
        default:
            return nil;
    }
}

- (NSString *)audienceFromType:(MSALAudienceType)audienceType error:(NSError **)error
{
    NSError *msidError = nil;
    
    switch (audienceType) {
        case MSALAzureADAndPersonalMicrosoftAccountAudience:
        {
            return @"common";
        }
        case MSALAzureADMultipleOrgsAudience:
        {
            return @"organizations";
        }
        case MSALAzureADMyOrgOnlyAudience:
        {
            msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Invalid MSALAudienceType provided. You must provide rawTenant when using MSALAzureADMyOrgOnlyAudience.", nil, nil, nil, nil, nil);;
            break;
        }
        case MSALPersonalMicrosoftAccountAudience:
        {
            return @"consumers";
        }
            
        default:
        {
            msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Invalid MSALAudienceType provided. You must provide rawTenant when using MSALAzureADMyOrgOnlyAudience.", nil, nil, nil, nil, nil);
            break;
        }
    }
    
    if (msidError && error)
    {
        *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    }
    
    return nil;
}

- (NSURL *)url
{
    return self.msidAuthority.url;
}

@end
