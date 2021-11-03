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

/**
    MSALAuthority represents an identity provider instance that MSAL can use to obtain tokens. For AAD it is of the form https://aad_instance/aad_tenant, where aad_instance is the
    directory host (e.g. https://login.microsoftonline.com) and aad_tenant is a identifier within the directory itself (e.g. a domain associated to the tenant, such as contoso.onmicrosoft.com, or the GUID representing the TenantID property of the directory)
 
    @note The MSALAuthority class is the base abstract class for the MSAL authority classes. Don't try to create instance of it using alloc or new. Instead, either create one of its subclasses directly (MSALAADAuthority, MSALB2CAuthority) or use the factory method `authorityWithURL:error:` to create subclasses using an authority URL.
*/
@interface MSALAuthority : NSObject <NSCopying>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Getting a normalized authority URL

/**
    Normalized authority URL.
 */
@property (atomic, readonly, nonnull) NSURL *url;

#pragma mark - Unavailable initializers

/**
   @note Use `[MSALAuthority authorityWithURL:error:]` instead
*/
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
   @note Use `[MSALAuthority authorityWithURL:error:]` instead
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

#pragma mark - Constructing MSALAuthority

/**

    Factory method that parses input authority URL and tries to detect its type automatically.
    @note This initializer will work in most AAD and some B2C cases. However, some valid authorities might be misclassified.
    Initialize `MSALAADAuthority` or `MSALB2CAuthority` directly for better reliability.
 
    @param     url                    Authority URL that MSAL can use to obtain tokens.
    @param     error               The error that occurred creating the authority, if any, if you're not interested in the specific error pass in nil.
*/
+ (nullable MSALAuthority *)authorityWithURL:(nonnull NSURL *)url
                                       error:(NSError * _Nullable __autoreleasing * _Nullable)error;

NS_ASSUME_NONNULL_END

@end
