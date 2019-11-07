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

#import <Foundation/Foundation.h>
#import "MSALAuthority.h"

/**
The sign-in audience specifies what kind of accounts you want to support in your app depending on the business needs for your application:
 
 For example, if you're building an application that will be only used in your organization, you can specify MSALAudienceType as MSALAzureADMyOrgOnlyAudience, and specify what organization it is by passing its tenant ID
 
 If your app will be used by multiple organizations and you want to sign-in users with both their work and school accounts, you can specify MSALAudienceType as MSALAzureADAndPersonalMicrosoftAccountAudience.

 Note that effective audience will be also dependent on what you specify in your application registration. For example, if you specify sign in audience as My Org Only in your app registration, and in MSAL as Multiple Orgs, the effective audience for your application will be the minimum of those two (My Org Only). See instructions here: https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#register-a-new-application-using-the-azure-portal
*/
typedef NS_ENUM(NSInteger, MSALAudienceType)
{
    
/**
    Users with a personal Microsoft account, or a work or school account in any organization’s Azure AD tenant
    Maps to https://[instance]/common/
*/
    MSALAzureADAndPersonalMicrosoftAccountAudience,
    
/**
    Users with a Microsoft work or school account in any organization’s Azure AD tenant (i.e. multi-tenant).
    Maps to https://[instance]/organizations/
*/
    MSALAzureADMultipleOrgsAudience,
    
/**
    Users with a Microsoft work or school account in my organization’s Azure AD tenant (i.e. single tenant).
    Maps to https://[instance]/[tenantId]
 */
    MSALAzureADMyOrgOnlyAudience,
    
/**
    Users with a personal Microsoft account. Maps to https://[instance]/consumers/
 */
    MSALPersonalMicrosoftAccountAudience
};

/**
    All the national clouds authenticate users separately in each environment and have separate authentication endpoints.
    MSALAzureCloudInstance represents a national cloud environment that should be used for authentication.
    See instructions here: https://docs.microsoft.com/en-us/azure/active-directory/develop/authentication-national-cloud
 */

typedef NS_ENUM(NSInteger, MSALAzureCloudInstance)
{
    /**
     Microsoft Azure public cloud. Maps to https://login.microsoftonline.com
    */
    MSALAzurePublicCloudInstance,
    
    /**
     Microsoft Chinese national cloud. Maps to https://login.chinacloudapi.cn
    */
    MSALAzureChinaCloudInstance,
    
    /**
     Microsoft German national cloud ("Black Forest"). Maps to https://login.microsoftonline.de
    */
    MSALAzureGermanyCloudInstance,
    
    /**
     US Government cloud. Maps to https://login.microsoftonline.us
    */
    MSALAzureUsGovernmentCloudInstance
};

/**
    An Azure Active Directory (AAD) authority indicating a directory that MSAL can use to obtain tokens. For AAD it is of the form https://aad_instance/aad_tenant, where aad_instance is the
    directory host (e.g. login.microsoftonline.com) and aad_tenant is a identifier within the directory itself (e.g. a domain associated to the tenant, such as contoso.onmicrosoft.com, or the GUID representing the TenantID property of the directory)
 */
@interface MSALAADAuthority : MSALAuthority

#pragma mark - Initializing MSALAADAuthority with a URL

/**
 Initializes MSALAADAuthority with NSURL.
 @param     url                 Authority indicating a directory that MSAL can use to obtain tokens. In Azure AD
                                it is of the form https://aad_instance/aad_tenant, where aad_instance is the
                                directory host (e.g. https://login.microsoftonline.com) and aad_tenant is a
                                identifier within the directory itself (e.g. a domain associated to the
                                tenant, such as contoso.onmicrosoft.com, or the GUID representing the
                                TenantID property of the directory)
 @param     error               The error that occurred creating the authority object, if any, if you're
                                not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
 Initializes MSALAADAuthority with NSURL and tenant ID.
 @param     url                 Authority indicating a directory that MSAL can use to obtain tokens. In Azure AD
                                it is of the form https://aad_instance/aad_tenant, where aad_instance is the
                                directory host (e.g. https://login.microsoftonline.com) and aad_tenant is a
                                identifier within the directory itself (e.g. a domain associated to the
                                tenant, such as contoso.onmicrosoft.com, or the GUID representing the
                                TenantID property of the directory)
 @param     rawTenant           GUID representing the TenantID of your Azure Active Directory
 @param     error                    The error that occurred creating the authority object, if any, if you're
                                not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                           rawTenant:(nullable NSString *)rawTenant
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error NS_DESIGNATED_INITIALIZER;

#pragma mark - Initializing MSALAADAuthority with a cloud instance and a sign-in audience

/**
 Initializes MSALAADAuthority with a cloud instance, audience type and an optional tenant ID.
 @param     cloudInstance       Azure AD authentication endpoint in a national cloud (see `MSALAzureCloudInstance`)
 @param     audienceType        The sign-in audience for the authority (see `MSALAudienceType`)
 @param     rawTenant           GUID representing the TenantID of your Azure Active Directory
 @param     error               The error that occurred creating the authority object, if any, if you're
                                not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithCloudInstance:(MSALAzureCloudInstance)cloudInstance
                                  audienceType:(MSALAudienceType)audienceType
                                     rawTenant:(nullable NSString *)rawTenant
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
 Initializes MSALAADAuthority with a cloud instance, audience type and an optional tenant ID.
 @param     environment         Host of Azure AD authentication endpoint in a national cloud (e.g. "login.microsoftonline.com" or "login.microsoftonline.de")
 @param     audienceType        The sign-in audience for the authority (see `MSALAudienceType`)
 @param     rawTenant           GUID representing the TenantID of your Azure Active Directory
 @param     error               The error that occurred creating the authority object, if any, if you're
                                not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithEnvironment:(nonnull NSString *)environment
                                audienceType:(MSALAudienceType)audienceType
                                   rawTenant:(nullable NSString *)rawTenant
                                       error:(NSError * _Nullable __autoreleasing * _Nullable)error;



@end
