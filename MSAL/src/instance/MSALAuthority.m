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
#import "MSALAadAuthority.h"
#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"
#import "MSALURLSession.h"
#import "MSALTenantDiscoveryResponse.h"

#define mustOverride() \
[NSException exceptionWithName:NSGenericException \
                        reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] \
                      userInfo:nil]


@implementation MSALAuthority

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


+ (void)createAndResolveEndpointsForAuthority:(NSURL *)unvalidatedAuthority
                            userPrincipalName:(NSString *)userPrincipalName
                                     validate:(BOOL)validate
                                      context:(id<MSALRequestContext>)context
                              completionBlock:(MSALAuthorityCompletion)completionBlock
{
    (void)userPrincipalName;
    (void)validate;
    
    // update the authority URL
    NSError *error = nil;
    NSURL *updatedAuthority = [self checkAuthorityString:unvalidatedAuthority.absoluteString error:&error];
    if (error)
    {
        completionBlock(nil, error);
    }
    
    // Check for authority type and create an updated URL
    MSALAuthority *authority = nil;
    MSALAuthorityType authorityType;

    NSString *firstPathComponent = unvalidatedAuthority.pathComponents[1];
    if ([firstPathComponent isEqualToString:@"tfp"])
    {
        // TODO: B2C
        authorityType = B2CAuthority;
        @throw @"Todo";
        return;
    }
    else if ([firstPathComponent isEqualToString:@"adfs"])
    {
        // TODO: ADFS
        authorityType = ADFSAuthority;
        @throw @"Todo";
        return;
    }
    else
    {
        authorityType = AADAuthority;
        
        NSURLSession *session = [MSALURLSession createSesssionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                                        context:context];
        authority = [[MSALAadAuthority alloc] initWithContext:context session:session];
        authority.canonicalAuthority = updatedAuthority;
    }
    
    // If exists in cache, return
    if ([authority retrieveFromValidatedAuthorityCache:userPrincipalName])
    {
        // YES!
        completionBlock(authority, nil);
        return;
    }
    
    // If not, continue.
    authority.isTenantless = isTenantless(unvalidatedAuthority);
    [authority openIdConfigurationEndpointForUserPrincipalName:userPrincipalName
                                             completionHandler:^(NSString *endpoint, NSError *error)
    {
        CHECK_COMPLETION(!error);
        
        NSURL *endpointURL = [NSURL URLWithString:endpoint];
        CHECK_ERROR_COMPLETION(endpointURL, authority.context, MSALErrorInvalidParameter, @"qwe");
        
        [authority tenantDiscoveryEndpoint:endpointURL
                           completionBlock:^(MSALTenantDiscoveryResponse *response, NSError *url) {
                               (void)response;
                               (void)url;
                           }];
    }];
}

- (void)tenantDiscoveryEndpoint:(NSURL *)url
                completionBlock:(void (^)(MSALTenantDiscoveryResponse *response, NSError *url))completionBlock
{
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:url
                                                            session:self.session
                                                            context:self.context];
    
    [request sendGet:^(NSError *error, MSALHttpResponse *response) {
        CHECK_COMPLETION(!error);
        
        NSError *jsonError = nil;
        MSALTenantDiscoveryResponse *tenantDiscoveryResponse = [[MSALTenantDiscoveryResponse alloc] initWithData:response.body
                                                                                                           error:&jsonError];
        if (jsonError)
        {
            completionBlock(nil, jsonError);
            return;
        }
        
        completionBlock(tenantDiscoveryResponse, nil);
    }];
}


+ (BOOL)isKnownHost:(NSURL *)url
{
    (void)url;
    @throw @"TODO";
    return NO;
}

#pragma mark - Instance methods

- (id)initWithContext:(id<MSALRequestContext>)context session:(NSURLSession *)session
{
    self = [super init];
    if (self) {
        _session = session;
        _context = context;
    }
    return self;
}

- (void)openIdConfigurationEndpointForUserPrincipalName:(NSString *)userPrincipalName
                                      completionHandler:(void (^)(NSString *, NSError *))completionHandler
{
    (void)userPrincipalName;
    (void)completionHandler;
    mustOverride();
}


- (void)addToValidatedAuthorityCache:(NSString *)userPrincipalName
{
    (void)userPrincipalName;
    mustOverride();
}

- (BOOL)retrieveFromValidatedAuthorityCache:(NSString *)userPrincipalName
{
    (void)userPrincipalName;
    mustOverride();
    return NO;
}

- (NSString *)defaultOpenIdConfigurationEndpoint
{
    mustOverride();
    return nil;
}

@end
