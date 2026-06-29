//
//  Configuration.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-27.
//

import Foundation

/// Sample app configuration.
/// Replace these values with your own CIAM tenant settings.
enum Configuration {
    /// The client ID of the application registered in the CIAM tenant.
    static let clientId = "6d0926a3-67d7-45b7-b429-9c25b0a699f7"

    /// The tenant subdomain (e.g., "contoso" for contoso.ciamlogin.com).
    static let tenantSubdomain = "oobselfservice2"

    /// The tenant ID (directory GUID) for the CIAM tenant. Will be removed later once tenant subdomain is enough
    static let tenantId = "40e32adb-2fb9-4616-8604-d73950c432f1"

    /// Optional ESTS slice/datacenter (`dc`) for test-slice targeting. Set to `nil` for production.
    static let dc: String? = nil
}
