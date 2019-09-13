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

#import <MSAL/MSAL.h>

#import "SamplePhotoUtil.h"

#import "SampleAppErrors.h"
#import "SampleGraphRequest.h"
#import "SampleMSALUtil.h"

@interface SamplePhotoRequest : SampleGraphRequest

- (void)getPhotoData:(void (^)(NSData *data, NSError *error))photoBlock;

@end


@implementation SamplePhotoUtil
{
    UIImage *_currentUserPhoto;
}

+ (instancetype)sharedUtil
{
    static SamplePhotoUtil *s_sharedUtil = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_sharedUtil = [SamplePhotoUtil new];
    });
    
    return s_sharedUtil;
}

- (void)getPhoto:(NSString *)token
           block:(PhotoBlock)photoBlock
{
    
    SamplePhotoRequest *request = [SamplePhotoRequest requestWithToken:token];
    [request getPhotoData:^(NSData *data, NSError *error) {
        if (error)
        {
            photoBlock(nil, error);
            return;
        }
        
        [self setLastChecked];
        if (!data)
        {
            NSLog(@"No data returned from graph for photo");
            photoBlock([UIImage imageNamed:@"no_photo"], nil);
            return;
        }
        
        UIImage *image = [[UIImage alloc] initWithData:data];
        if (!image)
        {
            photoBlock(nil, [NSError errorWithDomain:SampleAppErrorDomain
                                                code:SampleAppFailedToMakeUIImageError
                                            userInfo:nil]);
            return;
        }
        
        [self cachePhoto:data];
        _currentUserPhoto = image;
        photoBlock(image, nil);
    }];
}

- (void)checkUpdatePhotoWithParentController:(UIViewController *)controller completion:(PhotoBlock)photoBlock
{
    if (![self checkTimestamp])
    {
        return;
    }
    
    [self getUserPhotoImplWithParentController:controller
                                    completion:^(UIImage *photo, NSError *error)
     {
        dispatch_async(dispatch_get_main_queue(), ^{
            photoBlock(photo, error);
        });
     }];
}

- (void)getUserPhotoImplWithParentController:(UIViewController *)controller completion:(PhotoBlock)photoBlock
{
    // When acquiring a token for a specific purpose you should limit the scopes
    // you ask for to just the ones needed for that operation. A user or admin might not
    // consent to all of the scopes asked for, and core application functionality should
    // not be blocked on not having consent for edge features.
    __block NSArray *scopesRequired = @[@"User.Read"];
    
    [[SampleMSALUtil sharedUtil] acquireTokenForCurrentAccount:scopesRequired
                                              parentController:controller
                                               completionBlock:^(NSString *token, NSError *error)
     {
         if (error)
         {
             photoBlock(nil, error);
             return;
         }
         
         [self getPhoto:token block:photoBlock];
     }];
}


static NSString * const kLastPhotoCheck = @"last_photo_check";

- (void)clearPhotoCache
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastPhotoCheck];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:[self cachedImagePath] error:&error])
    {
        NSLog(@"Failed to remove cache file: %@", error);
    }
    
    _currentUserPhoto = nil;
}

- (void)setLastChecked
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastPhotoCheck];
}

#define SECONDS_PER_DAY 3600 * 24

- (NSString *)cachedImageDirectory
{
    NSArray<NSString *> *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [NSString stringWithFormat:@"%@/com.microsoft.MSALSampleApp/userphoto", directories[0]];
}

- (NSString *)cachedImagePath
{
    return [NSString stringWithFormat:@"%@/%@", [self cachedImageDirectory], [[SampleMSALUtil sharedUtil] currentAccountIdentifer]];
}

- (BOOL)checkTimestamp
{
    NSString *cachedImagePath = [self cachedImagePath];
    if (!cachedImagePath)
    {
        return YES;
    }
    
    NSDate *lastChecked = [[NSUserDefaults standardUserDefaults] objectForKey:kLastPhotoCheck];
    if (!lastChecked)
    {
        return YES;
    }
    
    BOOL cachedFileExists = [[NSFileManager defaultManager] fileExistsAtPath:cachedImagePath];
    if (cachedFileExists)
    {
        return (-[lastChecked timeIntervalSinceNow] > SECONDS_PER_DAY * 7);
    }
    else
    {
        return (-[lastChecked timeIntervalSinceNow] > SECONDS_PER_DAY);
    }
}

- (UIImage *)cachedPhoto
{
    if (_currentUserPhoto)
    {
        return _currentUserPhoto;
    }
    
    NSString *cachedImagePath = [self cachedImagePath];
    if (!cachedImagePath)
    {
        _currentUserPhoto = [UIImage imageNamed:@"no_photo"];
        return _currentUserPhoto;
    }
    
    UIImage *cachedImage = [UIImage imageWithContentsOfFile:cachedImagePath];
    if (!cachedImage)
    {
        cachedImage = [UIImage imageNamed:@"no_photo"];
    }
    
    _currentUserPhoto = cachedImage;
    return cachedImage;
}

- (void)cachePhoto:(NSData *)data
{
    NSString *cachedImageDirectory = [self cachedImageDirectory];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachedImageDirectory])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachedImageDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    [data writeToFile:[self cachedImagePath] atomically:NO];
}

@end

@implementation SamplePhotoRequest

- (void)getMetadata:(void (^)(NSDictionary *json, NSError *error))metadataBlock
{
    [self getJSON:@"me/photo" completionHandler:metadataBlock];
}

- (void)getPhotoData:(void (^)(NSData *data, NSError *error))photoBlock
{
    [self getMetadata:^(NSDictionary *json, NSError *error)
    {
        if (error || !json)
        {
            photoBlock(nil, error);
            return;
        }
        
        [self getData:@"me/photo/$value" completionHandler:photoBlock];
    }];
}

@end
