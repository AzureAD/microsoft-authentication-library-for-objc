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
#import "MSIDConstants.h"

NSString *MSALStringForPromptType(MSALPromptType promptType)
{
    switch (promptType)
    {
            STRING_CASE(MSALPromptTypeSelectAccount);
            STRING_CASE(MSALPromptTypeLogin);
            STRING_CASE(MSALPromptTypeConsent);
            STRING_CASE(MSALPromptTypeCreate);
            STRING_CASE(MSALPromptTypePromptIfNecessary);
    }
    
    @throw @"Unrecognized MSALPromptType";
}

MSIDPromptType MSIDPromptTypeForPromptType(MSALPromptType promptType)
{
    switch (promptType)
    {
        case MSALPromptTypeLogin : return MSIDPromptTypeLogin;
        case MSALPromptTypeConsent : return MSIDPromptTypeConsent;
        case MSALPromptTypeCreate : return MSIDPromptTypeCreate;
        case MSALPromptTypeSelectAccount : return MSIDPromptTypeSelectAccount;
        case MSALPromptTypePromptIfNecessary : return MSIDPromptTypePromptIfNecessary;
        default : return MSIDPromptTypeDefault;
    }
}

NSString *MSALParameterStringForPromptType(MSALPromptType promptType)
{
    switch (promptType)
    {
        case MSALPromptTypeLogin : return @"login";
        case MSALPromptTypeConsent : return @"consent";
        case MSALPromptTypeCreate : return @"create";
        case MSALPromptTypeSelectAccount : return @"select_account";
        case MSALPromptTypePromptIfNecessary : return @"";
    }
}
