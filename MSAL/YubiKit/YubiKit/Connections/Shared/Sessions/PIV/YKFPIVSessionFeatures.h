// Copyright 2018-2021 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef YKFPIVSessionFeatures_h
#define YKFPIVSessionFeatures_h

@class YKFFeature;

@interface YKFPIVSessionFeatures : NSObject
    @property (nonatomic, readonly) YKFFeature * _Nonnull usagePolicy;
    @property (nonatomic, readonly) YKFFeature * _Nonnull aesKey;
    @property (nonatomic, readonly) YKFFeature * _Nonnull serial;
    @property (nonatomic, readonly) YKFFeature * _Nonnull metadata;
    @property (nonatomic, readonly) YKFFeature * _Nonnull attestation;
    @property (nonatomic, readonly) YKFFeature * _Nonnull p384;
    @property (nonatomic, readonly) YKFFeature * _Nonnull touchCached;
@end

#endif /* YKFPIVSessionFeatures_h */
