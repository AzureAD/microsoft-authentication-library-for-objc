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

#import "MSALWebAuthResponse.h"
#import "MSALHttpResponse.h"
#import "MSALPkeyAuthHelper.h"
#import "MSALError.h"

@interface MSALWebAuthResponse()

{
    MSALWebAuthRequest *_request;
    id<MSALRequestContext> _context;
}

@end


@implementation MSALWebAuthResponse

NSString *const s_kWwwAuthenticateHeader = @"Accept";

+ (void)processResponse:(MSALHttpResponse *)response
                request:(MSALWebAuthRequest *)request
                context:(id<MSALRequestContext>)context
      completionHandler:(MSALHttpRequestCallback)completionHandler
{
    MSALWebAuthResponse *webAuthResponse = [MSALWebAuthResponse new];
    webAuthResponse->_request = request;
    webAuthResponse->_context = context;
    
    [webAuthResponse handleResponse:response
                  completionHandler:completionHandler];
    
}


- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    return self;
}


- (void)handleResponse:(MSALHttpResponse *)response
     completionHandler:(MSALHttpRequestCallback)completionHandler
{
    switch (response.statusCode) {
        case 200:
            completionHandler(nil, response);
            break;
        
        case 400:
        case 401:
        {
            NSString *wwwAuthValue = [response.headers valueForKey:s_kWwwAuthenticateHeader];
            
            if (![NSString msalIsStringNilOrBlank:wwwAuthValue])
            {
                if(wwwAuthValue.length > 0 &&
                   [wwwAuthValue rangeOfString:MSALPKeyAuthName].location != NSNotFound)
                {
                    [self handlePKeyAuthChallange:wwwAuthValue
                                completionHandler:completionHandler];
                    
                    return;
                }
            }
            
            completionHandler(nil, response);
            break;
        }
            
        case 500:
        case 503:
        case 504:
        {
            // retry if it is a server error
            // 500, 503 and 504 are the ones we retry
            if (_request.retryIfServerError)
            {
                _request.retryIfServerError = NO;

                // retry once after hald second
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [_request resend:completionHandler];
                });
                return;
            }
            //no "break;" here
            //will go to default for handling if "retryIfServerError" is NO
        }
        default:
        {
            // TODO: Check for right error code and details.
            //   Perhaps a utility class to generate NSError would be nice
            NSString *body = [[NSString alloc] initWithData:response.body encoding:NSUTF8StringEncoding];
            NSString *errorData = [NSString stringWithFormat:@"Full response: %@", body];
            
            NSString* message = [NSString stringWithFormat:@"Error raised: (Domain: \"%@\" Response Code: %ld \n%@", @"Domain", (long)response.statusCode, errorData];
            
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: message};
            
            NSError *error = [NSError errorWithDomain:@"Domain"
                                                 code:MSALErrorNetworkFailure
                                             userInfo:userInfo];
            
            LOG_WARN(_context, @"%@", message);
            
            completionHandler(error, response);
            
            break;
        }
    }
}

- (void)handlePKeyAuthChallange:(NSString *)wwwAuthHeaderValue
              completionHandler:(MSALHttpRequestCallback)completionHandler
{
    (void)wwwAuthHeaderValue;
    (void)completionHandler;
    
    
    //pkeyauth word length=8 + 1 whitespace
    wwwAuthHeaderValue = [wwwAuthHeaderValue substringFromIndex:[MSALPKeyAuthName length] + 1];
    
    NSDictionary* authHeaderParams = [self authHeaderParams:wwwAuthHeaderValue];
    
    if (!authHeaderParams)
    {
        LOG_ERROR(_context, @"Unparseable wwwAuthHeader received.");
    }

    NSError *error = nil;
    // TODO: MSALPkeyAuthHelper implementation
    NSString *authHeader = [MSALPkeyAuthHelper createDeviceAuthResponse:_request.endpointURL.absoluteString
                                                          challengeData:authHeaderParams
                                                          correlationId:[_context correlationId]
                                                                  error:&error];
    
    if (!authHeader)
    {
        completionHandler(error, nil);
        return;
    }
    
    // Add Authorization response header to the headers of the request
    [_request addValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [_request resend:completionHandler];
}


// Decodes the parameters that come in the Authorization header. We expect them in the following
// format:
//
// <key>="<value>", key="<value>", key="<value>"
// i.e. version="1.0",CertAuthorities="OU=MyOrganization,CN=MyThingy,DN=windows,DN=net,Context="context!"
//
// This parser is lenient on whitespace, and on the presence of enclosing quotation marks. It also
// will allow commented out quotation marks

- (NSDictionary *)authHeaderParams:(NSString *)headerValue
{
    NSMutableDictionary* params = [NSMutableDictionary new];
    NSUInteger strLength = [headerValue length];
    NSRange currentRange = NSMakeRange(0, strLength);
    NSCharacterSet* whiteChars = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet* alphaNum = [NSCharacterSet alphanumericCharacterSet];
    
    while (currentRange.location < strLength)
    {
        // Eat up any whitepace at the beginning
        while (currentRange.location < strLength && [whiteChars characterIsMember:[headerValue characterAtIndex:currentRange.location]])
        {
            ++currentRange.location;
            --currentRange.length;
        }
        
        if (currentRange.location == strLength)
        {
            return params;
        }
        
        if (![alphaNum characterIsMember:[headerValue characterAtIndex:currentRange.location]])
        {
            // malformed string
            return nil;
        }
        
        // Find the key
        NSUInteger found = [headerValue rangeOfString:@"=" options:0 range:currentRange].location;
        // If there are no keys left then exit out
        if (found == NSNotFound)
        {
            // If there still is string left that means it's malformed
            if (currentRange.length > 0)
            {
                return nil;
            }
            
            // Otherwise we're at the end, return params
            return params;
        }
        NSUInteger length = found - currentRange.location;
        NSString* key = [headerValue substringWithRange:NSMakeRange(currentRange.location, length)];
        
        // don't want the '='
        ++length;
        currentRange.location += length;
        currentRange.length -= length;
        
        NSString* value = nil;
        
        
        if ([headerValue characterAtIndex:currentRange.location] == '"')
        {
            ++currentRange.location;
            --currentRange.length;
            
            found = currentRange.location;
            
            do {
                NSRange range = NSMakeRange(found, strLength - found);
                found = [headerValue rangeOfString:@"\"" options:0 range:range].location;
            } while (found != NSNotFound && [headerValue characterAtIndex:found-1] == '\\');
            
            // If we couldn't find a matching closing quote then we have a malformed string and return NULL
            if (found == NSNotFound)
            {
                return nil;
            }
            
            length = found - currentRange.location;
            value = [headerValue substringWithRange:NSMakeRange(currentRange.location, length)];
            
            ++length;
            currentRange.location += length;
            currentRange.length -= length;
            
            // find the next comma
            found = [headerValue rangeOfString:@"," options:0 range:currentRange].location;
            if (found != NSNotFound)
            {
                length = found - currentRange.location;
            }
            
        }
        else
        {
            found = [headerValue rangeOfString:@"," options:0 range:currentRange].location;
            // If we didn't find the comma that means we're at the end of the list
            if (found == NSNotFound)
            {
                length = currentRange.length;
            }
            else
            {
                length = found - currentRange.location;
            }
            
            value = [headerValue substringWithRange:NSMakeRange(currentRange.location, length)];
        }
        
        NSString* existingValue = [params valueForKey:key];
        if (existingValue)
        {
            [params setValue:[existingValue stringByAppendingFormat:@".%@", value] forKey:key];
        }
        else
        {
            [params setValue:value forKey:key];
        }
        
        ++length;
        currentRange.location += length;
        currentRange.length -= length;
    }
    
    
    return params;
}


@end
