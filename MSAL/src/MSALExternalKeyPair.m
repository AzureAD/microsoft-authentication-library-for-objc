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

#import "MSALExternalKeyPair+Internal.h"
#import "MSALError.h"
#import "MSIDAssymetricKeyPair.h"
#import "MSIDKeyOperationUtil.h"

static MSALExternalKeyPairFailureReason MSALFailureReasonFromMSIDReason(MSIDExternalKeyPairValidationFailureReason reason)
{
    switch (reason)
    {
        case MSIDExternalKeyPairValidationFailureReasonNone:
            return MSALExternalKeyPairFailureReasonUnknown;

        case MSIDExternalKeyPairValidationFailureReasonInvalidKeyHandle:
            return MSALExternalKeyPairFailureReasonInvalidKeyHandle;

        case MSIDExternalKeyPairValidationFailureReasonUnsupportedKeyType:
            return MSALExternalKeyPairFailureReasonUnsupportedKeyType;

        case MSIDExternalKeyPairValidationFailureReasonKeySizeTooSmall:
            return MSALExternalKeyPairFailureReasonKeySizeTooSmall;

        case MSIDExternalKeyPairValidationFailureReasonInvalidKeyClass:
            return MSALExternalKeyPairFailureReasonInvalidKeyClass;

        case MSIDExternalKeyPairValidationFailureReasonNotSigningCapable:
            return MSALExternalKeyPairFailureReasonNotSigningCapable;

        case MSIDExternalKeyPairValidationFailureReasonKeyPairMismatch:
            return MSALExternalKeyPairFailureReasonKeyPairMismatch;

        case MSIDExternalKeyPairValidationFailureReasonPublicKeySerializationFailed:
            return MSALExternalKeyPairFailureReasonPublicKeySerializationFailed;

        case MSIDExternalKeyPairValidationFailureReasonPublicKeyDerivationFailed:
            return MSALExternalKeyPairFailureReasonPublicKeyDerivationFailed;
    }

    return MSALExternalKeyPairFailureReasonUnknown;
}

@implementation MSALExternalKeyPair

- (nullable instancetype)initWithPrivateKey:(SecKeyRef _Nullable)privateKey
                                  publicKey:(SecKeyRef _Nullable)publicKey
                                      error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSIDExternalKeyPairValidationFailureReason validationReason = MSIDExternalKeyPairValidationFailureReasonNone;
    NSError *validationError = nil;
    BOOL valid = [[MSIDKeyOperationUtil sharedInstance] validateExternalRSAKeyPair:privateKey
                                                                         publicKey:publicKey
                                                                     failureReason:&validationReason
                                                                           context:nil
                                                                             error:&validationError];
    if (!valid)
    {
        if (error)
        {
            NSString *description = validationError.localizedDescription ?: @"Invalid external AT PoP key pair.";
            NSMutableDictionary *userInfo = [@{
                MSALErrorDescriptionKey : description,
                MSALExternalKeyPairFailureReasonKey : @(MSALFailureReasonFromMSIDReason(validationReason))
            } mutableCopy];
            if (validationError)
            {
                userInfo[NSUnderlyingErrorKey] = validationError;
            }

            *error = [NSError errorWithDomain:MSALErrorDomain
                                         code:MSALErrorInvalidExternalKeyPair
                                     userInfo:userInfo];
        }

        return nil;
    }

    self = [super init];
    if (self)
    {
        // Caller-owned keys do not have MSAL keychain lookup metadata.
        _msidKeyPair = [[MSIDAssymetricKeyPair alloc] initWithPrivateKey:privateKey
                                                               publicKey:publicKey
                                                          privateKeyDict:[NSDictionary new]];
        if (!_msidKeyPair || !_msidKeyPair.kid)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:MSALErrorDomain
                                             code:MSALErrorInvalidExternalKeyPair
                                         userInfo:@{
                                             MSALErrorDescriptionKey : @"Unable to derive a public key thumbprint.",
                                             MSALExternalKeyPairFailureReasonKey : @(MSALExternalKeyPairFailureReasonPublicKeySerializationFailed)
                                         }];
            }

            return nil;
        }
    }

    return self;
}

- (NSString *)keyId
{
    return self.msidKeyPair.kid;
}

@end
