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

#import "SampleTODOsUtil.h"
#import "SampleAppErrors.h"
#import "SampleMSALUtil.h"
#import "SampleAPIRequest.h"

@implementation SampleTODO

+ (SampleTODO *)todoWithJson:(NSDictionary *)json
{
    SampleTODO *todo = [SampleTODO new];
    todo.title = json[@"title"];
    todo.owner = json[@"owner"];
    return todo;
}

@end

@interface SampleTodosRequest : SampleAPIRequest

- (void)getTodos:(void (^)(NSArray *todos, NSError *error))completionBlock;
- (void)addTodo:(NSString *)todo completion:(void (^)(NSError *error))completionBlock;

@end

static NSString * const kLastTodosCheck = @"last_todos_check";
static NSString * const kTodos = @"todos";

@interface SampleTODOsUtil()
{
    NSArray<SampleTODO *> *_cachedTodos;
}

@end

@implementation SampleTODOsUtil

+ (instancetype)sharedUtil
{
    static SampleTODOsUtil *s_util = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_util = [SampleTODOsUtil new];
    });
    
    return s_util;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }

    _cachedTodos = [self processTodos:[[NSUserDefaults standardUserDefaults] objectForKey:kTodos]];

    return self;
}

- (BOOL)checkTimestamp
{
    NSDate *lastChecked = [[NSUserDefaults standardUserDefaults] objectForKey:kLastTodosCheck];
    if (!lastChecked)
    {
        return YES;
    }

    // Only check for updated todos every 1 minute
    return (-[lastChecked timeIntervalSinceNow] > 1 * 60);
}

- (void)addTodoWithTitle:(NSString *)todoTitle completion:(void (^)(NSError *error))completionBlock
{
    [[SampleMSALUtil sharedUtil] acquireTokenForCurrentUser:@[@"api://a88bb933-319c-41b5-9f04-eff36d985612/access_as_user"]
                                            completionBlock:^(NSString *token, NSError *error)
     {
         if (error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(error);
             });
             return;
         }

         [[SampleTodosRequest requestWithToken:token] addTodo:todoTitle completion:completionBlock];
     }];
}

- (void)getTodosFromCache:(BOOL)useCache completion:(void (^)(NSArray<SampleTODO *> *todos, NSError *error))completionBlock
{
    if (![self checkTimestamp] && useCache)
    {
        completionBlock(_cachedTodos, nil);
        return;
    }
    
    [[SampleMSALUtil sharedUtil] acquireTokenForCurrentUser:@[@"api://a88bb933-319c-41b5-9f04-eff36d985612/access_as_user"]
                                            completionBlock:^(NSString *token, NSError *error)
     {
         if (error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error);
             });
             return;
         }
         
         [[SampleTodosRequest requestWithToken:token] getTodos:^(NSArray *todos, NSError *error)
          {
              [self setLastChecked];
              
              NSArray<SampleTODO *> *processedTodos = [self processTodos:todos];
              
              dispatch_async(dispatch_get_main_queue(), ^{
                  if (!error)
                  {
                      [self storeTodos:todos];
                      _cachedTodos = processedTodos;
                  }
                  
                  completionBlock(processedTodos, error);
              });
          }];
     }];
}

- (NSArray<SampleTODO *> *)processTodos:(NSArray *)todos
{
    if (!todos || ![todos isKindOfClass:[NSArray class]])
    {
        return nil;
    }
    
    NSMutableArray<SampleTODO *> *todosArray = [NSMutableArray new];

    for (NSDictionary *jsonTodo in todos)
    {
        if (![jsonTodo isKindOfClass:[NSDictionary class]])
        {
            return nil;
        }
        
        SampleTODO *todo = [SampleTODO todoWithJson:jsonTodo];
        if (!todo)
        {
            continue;
        }

        [todosArray addObject:todo];
    }
    
    return todosArray;
}

/*
 Returns cached todos (if any) for the current user
 */
- (NSArray<SampleTODO *> *)cachedTodos
{
    return _cachedTodos;
}

/*
 Clears any cached todos for the current user
 */
- (void)clearCache
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastTodosCheck];
    _cachedTodos = nil;
}

- (void)setLastChecked
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastTodosCheck];
}

- (void)storeTodos:(NSArray *)cachedTodos
{
    [[NSUserDefaults standardUserDefaults] setObject:cachedTodos forKey:kTodos];
}

@end

@implementation SampleTodosRequest

- (void)getTodos:(void (^)(NSArray *todos, NSError *error))completionBlock
{
    NSURL *url = [NSURL URLWithString:@"https://buildtodoservice.azurewebsites.net/api/todolist"];

    [super getJSONWithURL:url completionHandler:^(NSObject *todos, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }

         if (!todos || ![todos isKindOfClass:[NSArray class]])
         {
             completionBlock(nil, SA_ERROR(SampleAppServerInvalidResponseError, nil));
             return;
         }
         completionBlock((NSArray *)todos, nil);
     }];
}

- (void)addTodo:(NSString *)todo completion:(void (^)(NSError *error))completionBlock
{
    NSURL *url = [NSURL URLWithString:@"https://buildtodoservice.azurewebsites.net/api/todolist"];

    NSDictionary *dictionary = @{@"title": todo};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];

    [super postJSONWithURL:url json:jsonData completionHandler:^(NSData *data, NSError *error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(error);
        });
    }];
}

@end
