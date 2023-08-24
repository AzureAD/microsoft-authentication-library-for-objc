//
//  MSALNativeAuthErrorBasicAttributes.swift
//  MSAL
//
//  Created by marcos on 24/08/2023.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import Foundation

class MSALNativeAuthErrorBasicAttributes: NSObject, Decodable {
    let name: String
    
    init(name: String) {
        self.name = name
    }
}
