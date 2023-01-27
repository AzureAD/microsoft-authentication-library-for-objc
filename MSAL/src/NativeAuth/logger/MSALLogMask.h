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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSALLogMask : NSObject

/// Terms used in to clasify data:
/// - PII - Personally identifiable Information
/// - EUII - End User identifiable Information such as UPN, username, email
/// - EUPII - End User Pseudonymous Identifiers
/// - OII - Organization Identifiable Information

/// Used for masking any PII (Personally identifiable Information) including EUII and EUPI as long as log level is MSIDLogMaskingSettingsMaskAllPII
/// - Parameter parameter: Any object that needs to be masked
+ (MSIDMaskedLogParameter*) maskPII:(nullable id) parameter;

/// Used for masking any EUII (End User identifiable Information) such as UPN, username, email as long as log level is MSIDLogMaskingSettingsMaskEUIIOnly or below
/// - Parameter parameter: Any object that needs to be masked
+ (MSIDMaskedLogParameter*) maskEUII:(nullable id) parameter;

/// Used for masking any Trackable User Information such as Accounts or URLs that should be hashed as long as log level is MSIDLogMaskingSettingsMaskAllPII
/// - Parameter parameter: Any object that needs to be masked via hashing
+ (MSIDMaskedHashableLogParameter*) maskTrackablePII:(nullable id) parameter;

/// Used for masking any Username (email, id, account identifier) that should be hashed as long as log level is MSIDLogMaskingSettingsMaskEUIIOnly or below
/// - Parameter parameter: Any Username that needs to be masked via hashing
+ (MSIDMaskedUsernameLogParameter*) maskUsername:(nullable id) parameter;

@end

NS_ASSUME_NONNULL_END
