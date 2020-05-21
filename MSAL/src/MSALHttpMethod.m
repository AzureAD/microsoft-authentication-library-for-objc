//
//  MSALHttpMethod.m
//  MSAL
//
//  Created by Rohit Narula on 5/21/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDConstants.h"

NSString *MSALStringForHttpMethod(MSALHttpMethod httpMethod)
{
    switch (httpMethod)
    {
            STRING_CASE(MSALHttpMethodGET);
            STRING_CASE(MSALHttpMethodPOST);
    }
    
    @throw @"Unrecognized httpMethod";
}

MSIDHttpMethod MSIDHttpMethodForHttpMethod(MSALHttpMethod httpMethod)
{
    switch (httpMethod)
    {
        case MSALHttpMethodGET : return MSIDHttpMethodGET;
        case MSALHttpMethodPOST : return MSIDHttpMethodPOST;
        default : return MSIDHttpMethodGET;
    }
}

NSString *MSALParameterStringForHttpMethod(MSALHttpMethod httpMethod)
{
    switch (httpMethod)
    {
        case MSALHttpMethodGET : return @"GET";
        case MSALHttpMethodPOST : return @"POST";
    }
}
