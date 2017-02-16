//
//  MSALAadAuthority.m
//  MSAL
//
//  Created by Jason Kim on 2/14/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "MSALAadAuthority.h"
#import "MSALHttpRequest.h"
#import "MSALURLSession.h"
#import "MSALHttpResponse.h"
#import "MSALInstanceDiscoveryResponse.h"

@implementation MSALAadAuthority

#define TOKEN_ENDPOINT_SUFFIX           @"oauth2/v2.0/authorize"
#define AUTHORIZE_ENDPOINT_SUFFIX       @"oauth2/v2.0/token"

#define AAD_INSTANCE_DISCOVERY_ENDPOINT @"https://login.windows.net/common/discovery/instance"
#define API_VERSION                     @"api-version"
#define API_VERSION_VALUE               @"1.0"
#define AUTHORIZATION_ENDPOINT          @"authorization_endpoint"

#define DEFAULT_OPENID_CONFIGURATION_ENDPOINT @"v2.0/.well-known/openid-configuration"

static NSMutableDictionary<NSString *, MSALAuthority *> *s_validatedAuthorities;
static NSSet<NSString *> *s_trustedHostList;

BOOL isInTrustedHostList(NSString *host)
{
    return [s_trustedHostList containsObject:host.lowercaseString];
}

- (id)initWithContext:(id<MSALRequestContext>)context session:(NSURLSession *)session
{
    (void)context;
    (void)session;
    
    self = [super init];
    if (self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            s_validatedAuthorities = [NSMutableDictionary new];
            s_trustedHostList = [NSSet setWithObjects: @"login.windows.net",
                                    @"loginchinacloudapi.cn",
                                    @"login.cloudgovapi.us",
                                    @"login.microsoftonline.com",
                                    @"login.microsoftonline.de", nil];
        });
        self.authorityType = AADAuthority;
    }
    return self;
}

- (void)openIdConfigurationEndpointForUserPrincipalName:(NSString *)userPrincipalName
                                      completionHandler:(void (^)(NSString *endpoint, NSError *url))completionHandler

{
    (void)userPrincipalName;
    NSString *host = self.canonicalAuthority.host;
    NSString *tenant = self.canonicalAuthority.pathComponents[1];
    
    if (self.validateAuthority && !isInTrustedHostList(host))
    {
        MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:[NSURL URLWithString:AAD_INSTANCE_DISCOVERY_ENDPOINT]
                                                                session:self.session
                                                                context:self.context];
        
        [request addValue:API_VERSION_VALUE forHTTPHeaderField:API_VERSION];
        [request addValue:[NSString stringWithFormat:@"https://%@/%@/%@", host, tenant, TOKEN_ENDPOINT_SUFFIX] forHTTPHeaderField:AUTHORIZATION_ENDPOINT];
       
        [request sendGet:^(NSError *error, MSALHttpResponse *response) {
            if (error)
            {
                completionHandler(nil, error);
                return;
            }

            NSError *jsonError = nil;
            MSALInstanceDiscoveryResponse *json = [[MSALInstanceDiscoveryResponse alloc] initWithData:response.body
                                                                                                error:&jsonError];
            if (jsonError)
            {
                completionHandler(nil, error);
                return;
            }
            
            NSString *tenant_discover_endpoint = json.tenant_discovery_endpoint;
            
            if ([NSString msalIsStringNilOrBlank:tenant_discover_endpoint])
            {
                completionHandler(nil, MSAL_CREATE_ERROR_INVALID_RESULT(tenantEndpoint));
                return;
            }
            completionHandler(tenant_discover_endpoint, nil);
            return;
        }];
    }
    else
    {
        completionHandler([self defaultOpenIdConfigurationEndpoint], nil);
        return;
    }
}

- (NSString *)defaultOpenIdConfigurationEndpoint
{
    NSString *host = self.canonicalAuthority.host;
    NSString *tenant = self.canonicalAuthority.pathComponents[1];
    return [NSString stringWithFormat:@"https://%@/%@/%@", host, tenant, DEFAULT_OPENID_CONFIGURATION_ENDPOINT];   
}

- (void)addToValidatedAuthorityCache:(NSString *)userPrincipalName
{
    (void)userPrincipalName;
    s_validatedAuthorities[self.canonicalAuthority.absoluteString] = self;
}

- (BOOL)retrieveFromValidatedAuthorityCache:(NSString *)userPrincipalName
{
    (void)userPrincipalName;
    MSALAuthority *authorityFromCache = s_validatedAuthorities[self.canonicalAuthority.absoluteString];
    
    if (!authorityFromCache)
    {
        return NO;
    }
    
    self.authorityType = authorityFromCache.authorityType;
    self.canonicalAuthority = authorityFromCache.canonicalAuthority;
    self.validateAuthority = authorityFromCache.validateAuthority;
    self.isTenantless = authorityFromCache.isTenantless;
    self.authorizationEndpoint = authorityFromCache.authorizationEndpoint;
    self.tokenEndpoint = authorityFromCache.tokenEndpoint;
    self.endSessionEndpoint = authorityFromCache.tokenEndpoint;
    self.selfSignedJwtAudience = authorityFromCache.selfSignedJwtAudience;
    
    return YES;
}

- (BOOL)existsInValidatedAuthorityCache:(NSString *)userPrincipalName
{
    (void)userPrincipalName;
    return s_validatedAuthorities[self.canonicalAuthority.absoluteString] != nil;
}



@end
