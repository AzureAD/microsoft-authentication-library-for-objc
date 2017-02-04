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

extern NSString * MSALErrorDomain;

/*!
    The OAuth error returned by the service.
 */
extern NSString * MSALOAuthErrorKey;

/*!
    The extded error description returned by the service. Note that this string
    can change ands should not be relied upon for any error handling logic.
 */
extern NSString * MSALOAuthErrorDescriptionKey;

NS_ENUM(NSInteger)
{
    /*!
        Interaction required errors occur because of a wide variety of errors
        returned by the authentication service. In all cases the proper response
        is to use a MSAL interactive AcquireToken call with the same parameters.
        For more details check MSALOAuthErrorKey and MSALOAuthErrorDescriptionKey
        in the userInfo dictionary.
     */
    MSALErrorInteractionRequired    = -1000,
    MSALErrorMismatchedUser = -1001,
    
    MSALErrorKeychainFailure = -1002,
    MSALErrorNetworkFailure = -1003,
};

