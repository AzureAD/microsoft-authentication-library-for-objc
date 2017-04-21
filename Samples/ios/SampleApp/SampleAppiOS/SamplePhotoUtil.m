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

#import "SampleAppErrors.h"
#import "SamplePhotoUtil.h"
#import "SampleMSALUtil.h"

@interface SamplePhotoRequest : NSObject
{
    NSString *_token;
}

+ (instancetype)requestWithToken:(NSString *)token;

- (void)getPhotoData:(void (^)(NSData *data, NSError *error))photoBlock;

@end


@implementation SamplePhotoUtil


+ (void)getPhoto:(NSString *)token
           block:(PhotoBlock)photoBlock
{
    
    SamplePhotoRequest *request = [SamplePhotoRequest requestWithToken:token];
    [request getPhotoData:^(NSData *data, NSError *error) {
        if (error)
        {
            photoBlock(nil, error);
            return;
        }
        
        if (!data)
        {
            [self setLastChecked];
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
        
        
            photoBlock(image, nil);
    }];
}

+ (void)getUserPhoto:(PhotoBlock)photoBlock
{
    // Start by checking if we have a cached image available for this user
    UIImage *cached = [self checkPhotoCache];
    if (cached)
    {
        photoBlock(cached, nil);
        return;
    }
    
    [self getUserPhotoImpl:^(UIImage *photo, NSError *error)
     {
        dispatch_async(dispatch_get_main_queue(), ^{
            photoBlock(photo, error);
        });
     }];
}

+ (void)getUserPhotoImpl:(PhotoBlock)photoBlock
{
    // When acquiring a token silently for a specific purpose you should limit the scopes
    // you ask for to just the ones needed for that operation. A user or admin might not
    // consent to all of the scopes asked for, and core application functionality should
    // not be blocked on not having consent for edge features.
    __block NSArray *scopesRequired = @[@"User.Read"];
    
    [[SampleMSALUtil sharedUtil] acquireTokenSilentForCurrentUser:scopesRequired
                                                  completionBlock:^(NSString *token, NSError *error)
     {
         if (error)
         {
             // What an app does on an InteractionRequired error will vary from app to app. More complex apps
             // will usually want to present a notification to the user in an unobtrusive way (such as on a
             // status bar in the application UI). Simpler apps, like this one, can jump straight into the
             // acquireTokenInteractive flow.
             if ([error.domain isEqualToString:MSALErrorDomain] && error.code == MSALErrorInteractionRequired)
             {
                 [[SampleMSALUtil sharedUtil] acquireTokenInteractiveForCurrentUser:scopesRequired
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
             else
             {
                 photoBlock(nil, error);
             }
             return;
         }
         
         [self getPhoto:token block:photoBlock];
     }];
}


static NSString * const kLastPhotoCheck = @"last_photo_check";

+ (void)clearPhotoCache
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastPhotoCheck];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:[self cachedImagePath] error:&error])
    {
        NSLog(@"Failed to remove cache file: %@", error);
    }
}

+ (void)setLastChecked
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastPhotoCheck];
}

#define SECONDS_PER_DAY 3600 * 24

+ (NSString *)cachedImageDirectory
{
    NSArray<NSString *> *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [NSString stringWithFormat:@"%@/com.microsoft.MSALSampleApp/userphoto", directories[0]];
}

+ (NSString *)cachedImagePath
{
    return [NSString stringWithFormat:@"%@/%@", [self cachedImageDirectory], [[SampleMSALUtil sharedUtil] currentUserIdentifer]];
}

+ (UIImage *)checkPhotoCache
{
    NSString *cachedImagePath = [self cachedImagePath];
    if (!cachedImagePath)
    {
        return nil;
    }
    
    UIImage *cachedImage = [UIImage imageWithContentsOfFile:cachedImagePath];
    NSDate *lastChecked = [[NSUserDefaults standardUserDefaults] objectForKey:kLastPhotoCheck];
    if (!cachedImage)
    {
        // If we never had an image don't check more then once a day...?
        if (lastChecked && [lastChecked timeIntervalSinceNow] < SECONDS_PER_DAY)
        {
            return [UIImage imageNamed:@"no_photo"];
        }
    }
    else if ([lastChecked timeIntervalSinceNow] < SECONDS_PER_DAY * 7)
    {
        // If we've checked in less then 7 days just return the cached image
        return cachedImage;
    }
    
    return cachedImage;
}

+ (void)cachePhoto:(NSData *)data
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

+ (instancetype)requestWithToken:(NSString *)token
{
    SamplePhotoRequest *req = [SamplePhotoRequest new];
    req->_token = token;
    return req;
}

- (void)getMetadata:(void (^)(NSDictionary *json, NSError *error))metadataBlock
{
    NSMutableURLRequest *metadataRequest = [NSMutableURLRequest new];
    metadataRequest.URL = [NSURL URLWithString:@"https://graph.microsoft.com/v1.0/me/photo"];
    metadataRequest.HTTPMethod = @"GET";
    metadataRequest.allHTTPHeaderFields = @{ @"Authorization" : [NSString stringWithFormat:@"Bearer %@", _token] };
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:metadataRequest
               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
     {
         if (error)
         {
             metadataBlock(nil, error);
             return;
         }
         
         // If we get a 404 that means the user has no photo, just return all nils
         if (((NSHTTPURLResponse *)response).statusCode == 404)
         {
             metadataBlock(nil, nil);
             return;
         }
         
         NSError *localError = nil;
         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&localError];
         if (!json)
         {
             metadataBlock(nil, localError);
             return;
         }
         
         NSDictionary *serverError = json[@"error"];
         if (serverError)
         {
             metadataBlock(nil, [NSError errorWithDomain:SampleAppErrorDomain code:SampleAppServerError userInfo:serverError]);
             return;
         }
         
         metadataBlock(json, nil);
     }];
    [task resume];
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
        
        NSMutableURLRequest *photoRequest = [NSMutableURLRequest new];
        photoRequest.URL = [NSURL URLWithString:@"https://graph.microsoft.com/beta/me/photo/$value"];
        photoRequest.HTTPMethod = @"GET";
        photoRequest.allHTTPHeaderFields = @{ @"Authorization" : _token };
        
        NSURLSession *session = [NSURLSession sharedSession];
        
        NSURLSessionDataTask *task =
        [session dataTaskWithRequest:photoRequest
                   completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
         {
             
             photoBlock(data, error);
         }];
        
        [task resume];
    }];
}

@end
