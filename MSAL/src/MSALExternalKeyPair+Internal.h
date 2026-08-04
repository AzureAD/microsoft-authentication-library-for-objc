//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import "MSALExternalKeyPair.h"

@class MSIDAssymetricKeyPair;

NS_ASSUME_NONNULL_BEGIN

@interface MSALExternalKeyPair ()

@property (nonatomic) MSIDAssymetricKeyPair *msidKeyPair;

@end

NS_ASSUME_NONNULL_END
