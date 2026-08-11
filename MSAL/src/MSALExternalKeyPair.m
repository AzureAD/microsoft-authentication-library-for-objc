//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import "MSALExternalKeyPair+Internal.h"
#import "MSALError.h"
#import "MSIDAssymetricKeyPair.h"
#import "MSIDKeyOperationUtil.h"

NSString *const MSALExternalKeyPairFailureReasonKey = @"MSALExternalKeyPairFailureReasonKey";

@implementation MSALExternalKeyPair

- (instancetype)initWithPrivateKey:(SecKeyRef)privateKey
                         publicKey:(SecKeyRef)publicKey
                             error:(NSError *__autoreleasing *)error
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
            *error = [NSError errorWithDomain:MSALErrorDomain
                                         code:MSALErrorInvalidExternalKeyPair
                                     userInfo:@{
                                         MSALErrorDescriptionKey : description,
                                         MSALExternalKeyPairFailureReasonKey : @([self msalFailureReasonFromMSIDReason:validationReason])
                                     }];
        }

        return nil;
    }

    self = [super init];
    if (self)
    {
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

- (MSALExternalKeyPairFailureReason)msalFailureReasonFromMSIDReason:(MSIDExternalKeyPairValidationFailureReason)reason
{
    switch (reason)
    {
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

        case MSIDExternalKeyPairValidationFailureReasonNone:
        case MSIDExternalKeyPairValidationFailureReasonInvalidKeyHandle:
        default:
            return MSALExternalKeyPairFailureReasonInvalidKeyHandle;
    }
}

@end
