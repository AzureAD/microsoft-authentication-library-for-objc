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
    static let clientId = "Enter_the_Application_Id_Here"

    /// The tenant subdomain (e.g., "contoso" for contoso.ciamlogin.com).
    static let tenantSubdomain = "Enter_the_Tenant_Subdomain_Here"

    /// The base URL for the credential management API.
    /// Replace with your tenant's credential management endpoint.
    static let credentialManagementBaseURL = "https://\(tenantSubdomain).ciamlogin.com/api/v1.0"
}
