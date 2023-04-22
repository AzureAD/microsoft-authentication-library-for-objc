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

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

/** Project version number for MSAL */
FOUNDATION_EXPORT double MSAL__Framework_VersionNumber;

/** Project version string for MSAL */
FOUNDATION_EXPORT const unsigned char MSAL__Framework_VersionString[];

#import <MSAL/MSALDefinitions.h>
#import <MSAL/MSALRedirectUri.h>
#import <MSAL/MSALError.h>
#import <MSAL/MSALPublicClientApplicationConfig.h>
#import <MSAL/MSALGlobalConfig.h>
#import <MSAL/MSALLoggerConfig.h>
#import <MSAL/MSALTelemetryConfig.h>
#import <MSAL/MSALHTTPConfig.h>
#import <MSAL/MSALCacheConfig.h>
#import <MSAL/MSALPublicClientApplication.h>
#import <MSAL/MSALSliceConfig.h>
#import <MSAL/MSALResult.h>
#import <MSAL/MSALAccount.h>
#import <MSAL/MSALAccountId.h>
#import <MSAL/MSALTelemetry.h>
#import <MSAL/MSALAuthority.h>
#import <MSAL/MSALAADAuthority.h>
#import <MSAL/MSALB2CAuthority.h>
#import <MSAL/MSALADFSAuthority.h>
#import <MSAL/MSALPublicClientStatusNotifications.h>
#import <MSAL/MSALSilentTokenParameters.h>
#import <MSAL/MSALInteractiveTokenParameters.h>
#import <MSAL/MSALTokenParameters.h>
#import <MSAL/MSALClaimsRequest.h>
#import <MSAL/MSALIndividualClaimRequest.h>
#import <MSAL/MSALIndividualClaimRequestAdditionalInfo.h>
#import <MSAL/MSALJsonSerializable.h>
#import <MSAL/MSALJsonDeserializable.h>
#import <MSAL/MSALLogger.h>
#import <MSAL/MSALTelemetry.h>
#import <MSAL/MSALTenantProfile.h>
#import <MSAL/MSALAccount+MultiTenantAccount.h>
#import <MSAL/MSALAccountEnumerationParameters.h>
#import <MSAL/MSALExternalAccountProviding.h>
#import <MSAL/MSALWebviewParameters.h>
#import <MSAL/MSALSerializedADALCacheProvider.h>
#import <MSAL/MSALWebviewParameters.h>
#import <MSAL/MSALSignoutParameters.h>
#import <MSAL/MSALParameters.h>
#import <MSAL/MSALPublicClientApplication+SingleAccount.h>
#if TARGET_OS_IPHONE
#import <MSAL/MSALLegacySharedAccountsProvider.h>
#endif
#import <MSAL/MSALDeviceInformation.h>
#import <MSAL/MSALWPJMetaData.h>
#import <MSAL/MSALAuthenticationSchemeBearer.h>
#import <MSAL/MSALAuthenticationSchemePop.h>
#import <MSAL/MSALAuthenticationSchemeProtocol.h>
#import <MSAL/MSALHttpMethod.h>
#import <MSAL/MSALCIAMAuthority.h>
#import <MSAL/MSALWipeCacheForAllAccountsConfig.h>
