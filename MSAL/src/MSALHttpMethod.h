//
//  MSALHttpMethod.h
//  MSAL
//
//  Created by Rohit Narula on 5/21/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDConstants.h"

extern NSString *MSALStringForHttpMethod(MSALHttpMethod httpMethod);
extern MSIDHttpMethod MSIDHttpMethodForHttpMethod(MSALHttpMethod httpMethod);
extern NSString *MSALParameterStringForHttpMethod(MSALHttpMethod httpMethod);
