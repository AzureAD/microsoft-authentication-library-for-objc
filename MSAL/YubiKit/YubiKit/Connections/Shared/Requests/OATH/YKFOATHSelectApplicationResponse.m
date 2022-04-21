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

#import "YKFOATHSelectApplicationResponse.h"
#import "YKFAssert.h"
#import "YKFNSDataAdditions+Private.h"

typedef NS_ENUM(NSUInteger, YKFOATHSelectApplicationResponseTag) {
    YKFOATHSelectApplicationResponseTagName = 0x71,
    YKFOATHSelectApplicationResponseTagVersion = 0x79,
    YKFOATHSelectApplicationResponseTagChallenge = 0x74,
    YKFOATHSelectApplicationResponseTagAlgorithm = 0x7B
};

@interface YKFOATHSelectApplicationResponse()

@property (nonatomic, readwrite) NSData *selectID;
@property (nonatomic, readwrite) NSData *challenge;
@property (nonatomic, assign, readwrite) YKFOATHCredentialAlgorithm algorithm;
@property (nonatomic, readwrite) YKFVersion *version;

@end

@implementation YKFOATHSelectApplicationResponse

- (nullable instancetype)initWithResponseData:(NSData *)responseData {
    YKFAssertAbortInit(responseData.length);
    
    self = [super init];
    if (self) {
        UInt8 *bytes = (UInt8 *)responseData.bytes;
        NSUInteger readIndex = 0;
        
        UInt8 versionTag = bytes[readIndex];
        YKFAssertAbortInit(versionTag == YKFOATHSelectApplicationResponseTagVersion);
        
        ++readIndex;
        YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
        
        UInt8 lengthOfVersion = bytes[readIndex];
        YKFAssertAbortInit(lengthOfVersion >= 3);

        ++readIndex;
        NSRange versionRange = NSMakeRange(readIndex, lengthOfVersion);
        YKFAssertAbortInit([responseData ykf_containsRange:versionRange]);

        NSData *version = [responseData subdataWithRange:versionRange];
        UInt8 *versionBytes = (UInt8 *)version.bytes;
        YKFAssertAbortInit([responseData ykf_containsRange:versionRange]);

        self.version = [[YKFVersion alloc] initWithBytes:versionBytes[0] minor:versionBytes[1] micro:versionBytes[2]];

        readIndex += lengthOfVersion;
        YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
        
        UInt8 nameTag = bytes[readIndex];
        YKFAssertAbortInit(nameTag == YKFOATHSelectApplicationResponseTagName);
        
        ++readIndex;
        YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
        
        UInt8 lengthOfName = bytes[readIndex];
        YKFAssertAbortInit(lengthOfName > 0);
        
        ++readIndex;
        NSRange nameRange = NSMakeRange(readIndex, lengthOfName);
        YKFAssertAbortInit([responseData ykf_containsRange:nameRange]);
        
        NSData *nameData = [responseData subdataWithRange:nameRange];
        self.selectID = nameData;
        
        readIndex += lengthOfName;
        
        // Challenge is present
        if (readIndex < responseData.length) {
            UInt8 challengeTag = bytes[readIndex];
            YKFAssertAbortInit(challengeTag == YKFOATHSelectApplicationResponseTagChallenge);
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            UInt8 challengeLength = bytes[readIndex];
            YKFAssertAbortInit(challengeLength > 0);
            
            ++readIndex;
            NSRange challengeRange = NSMakeRange(readIndex, challengeLength);
            YKFAssertAbortInit([responseData ykf_containsRange:challengeRange]);
            self.challenge = [responseData subdataWithRange:NSMakeRange(readIndex, challengeLength)];
            
            if (self.version.major > 3) {
                // old NEO versions didn't have algorithm tag
                readIndex += challengeLength;
                YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
                UInt8 algorithmTag = bytes[readIndex];
                YKFAssertAbortInit(algorithmTag == YKFOATHSelectApplicationResponseTagAlgorithm);
                
                readIndex += 2; // 1 byte is length which is always 1
                YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
                self.algorithm = bytes[readIndex];
            }
        }
    }
    return self;
}

@end
