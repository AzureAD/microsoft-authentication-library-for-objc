// Copyright 2018-2019 Yubico AB
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

#import <Foundation/Foundation.h>

#define ykf_weak_self() __weak typeof(self) weakSelf = self

#define ykf_strong_self() __strong typeof(self) strongSelf = weakSelf
#define ykf_safe_strong_self() __strong typeof(self) strongSelf = weakSelf; if (!strongSelf) { return; }
