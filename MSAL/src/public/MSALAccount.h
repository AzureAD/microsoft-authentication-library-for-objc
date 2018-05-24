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

@interface MSALAccount : NSObject <NSCopying>

/*!
 The displayable value in UserPrincipleName(UPN) format. Can be nil if not returned from the service.
 */
@property (readonly) NSString *displayableId;

/*!
 The displayable name of the account. Can be nil if not returned by the service.
 */
@property (readonly) NSString *name;

/*!
 Unique identifier of the account in the home directory.
 */
@property (readonly) NSString *homeAccountId;

/*!
 Unique identifier of the account in the signed in directory.
 */
@property (readonly) NSString *localAccountId;

/*!
 Host part of the authority string used for authentication.
 */
@property (readonly) NSString *environment;

/*!
 An identifier for the tenant that the account was acquired from. This property will be nil if tenant information is not returned by the service.
 */
@property (readonly) NSString *tenantId;

@end

