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

#import "MSALAuthority.h"
#import "MSALError_Internal.h"
#import "MSALAadAuthorityResolver.h"
#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"
#import "MSALURLSession.h"
#import "MSALTenantDiscoveryResponse.h"

@implementation MSALAuthority

#define TENANT_ID_STRING_IN_PAYLOAD @"{tenantid}"

static NSSet<NSString *> *s_trustedHostList;

#pragma mark - helper functions
BOOL isTenantless(NSURL *authority)
{
    NSArray *authorityURLPaths = authority.pathComponents;
    
    NSString *tenameName = [authorityURLPaths[1] lowercaseString];
    if ([tenameName isEqualToString:@"common"] ||
        [tenameName isEqualToString:@"organizations"] ||
        [tenameName isEqualToString:@"consumers"] )
    {
        return YES;
    }
    return NO;
}



#pragma mark - class methods
+ (void)initialize
{
    s_trustedHostList = [NSSet setWithObjects: @"login.windows.net",
                         @"login.chinacloudapi.cn",
                         @"login.cloudgovapi.us",
                         @"login-us.microsoftonline.com",
                         @"login.microsoftonline.com",
                         @"login.microsoftonline.de", nil];
}


+ (NSURL *)checkAuthorityString:(NSString *)authority
                          error:(NSError * __autoreleasing *)error
{
    REQUIRED_STRING_PARAMETER(authority, nil);
    
    NSURL *authorityUrl = [NSURL URLWithString:authority];
    CHECK_ERROR_RETURN_NIL(authorityUrl, nil, MSALErrorInvalidParameter, @"\"authority\" must be a valid URI");
    CHECK_ERROR_RETURN_NIL([authorityUrl.scheme isEqualToString:@"https"], nil, MSALErrorInvalidParameter, @"authority must use HTTPS");
    CHECK_ERROR_RETURN_NIL((authorityUrl.pathComponents.count > 1), nil, MSALErrorInvalidParameter, @"authority must specify a tenant or common");
    
    // B2C
    if ([[authorityUrl.pathComponents[1] lowercaseString] isEqualToString:@"tfp"])
    {
        CHECK_ERROR_RETURN_NIL((authorityUrl.pathComponents.count > 2), nil, MSALErrorInvalidParameter, @"authority must specify a tenant");
        return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/tfp/%@", authorityUrl.host, authorityUrl.pathComponents[2]]];
    }
    
    // ADFS and AAD
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", authorityUrl.host, authorityUrl.pathComponents[1]]];
}


+ (void)resolveEndpointsForAuthority:(NSURL *)unvalidatedAuthority
                   userPrincipalName:(NSString *)userPrincipalName
                            validate:(BOOL)validate
                             context:(id<MSALRequestContext>)context
                     completionBlock:(MSALAuthorityCompletion)completionBlock
{
    NSError *error = nil;
    NSURL *updatedAuthority = [self checkAuthorityString:unvalidatedAuthority.absoluteString error:&error];
    CHECK_COMPLETION(!error);
    
    MSALAuthorityType authorityType;
    NSString *firstPathComponent = updatedAuthority.pathComponents[1].lowercaseString;
    NSString *tenant = nil;
    
    id<MSALAuthorityResolver> resolver;
    
    if ([firstPathComponent isEqualToString:@"tfp"])
    {
        authorityType = B2CAuthority;
        @throw @"TODO";
    }
    else if ([firstPathComponent isEqualToString:@"adfs"])
    {
        authorityType = ADFSAuthority;
        @throw @"TODO";
    }
    else
    {
        authorityType = AADAuthority;
        resolver = [MSALAadAuthorityResolver sharedResolver];
        tenant = firstPathComponent;
    }
    
    TenantDiscoveryCallback tenantDiscoveryCallback = ^void
    (MSALTenantDiscoveryResponse *response, NSError *error)
    {
        CHECK_COMPLETION(!error);

        MSALAuthority *authority = [MSALAuthority new];
        authority.canonicalAuthority = updatedAuthority;
        authority.authorityType = authorityType;
        authority.validateAuthority = validate;
        authority.isTenantless = isTenantless(updatedAuthority);
        
        NSString *authorizationEndpoint = [response.authorization_endpoint stringByReplacingOccurrencesOfString:TENANT_ID_STRING_IN_PAYLOAD withString:tenant];
        NSString *tokenEndpoint = [response.token_endpoint stringByReplacingOccurrencesOfString:TENANT_ID_STRING_IN_PAYLOAD withString:tenant];
        NSString *issuer = [response.issuer stringByReplacingOccurrencesOfString:TENANT_ID_STRING_IN_PAYLOAD withString:tenant];
        
        authority.authorizationEndpoint = [NSURL URLWithString:authorizationEndpoint];
        authority.tokenEndpoint = [NSURL URLWithString:tokenEndpoint];
        authority.endSessionEndpoint = nil;
        authority.selfSignedJwtAudience = issuer;
     
        [resolver addToValidatedAuthorityCache:authority userPrincipalName:userPrincipalName];
        
        completionBlock(authority, nil);
    };
    
    [resolver openIDConfigurationEndpointForURL:updatedAuthority
                              userPrincipalName:userPrincipalName
                                       validate:validate
                                        context:context
                              completionHandler:^(NSString *endpoint, NSError *error)
    {
        CHECK_COMPLETION(!error);
        
        [resolver tenantDiscoveryEndpoint:[NSURL URLWithString:endpoint]
                                  context:context completionBlock:tenantDiscoveryCallback];
        
    }];
}

+ (BOOL)isKnownHost:(NSURL *)url
{
    return [s_trustedHostList containsObject:url.host.lowercaseString];
}

@end
