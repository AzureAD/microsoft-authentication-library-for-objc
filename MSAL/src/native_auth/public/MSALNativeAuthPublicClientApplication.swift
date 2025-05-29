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

import Foundation

/// Main interface to interact with the Native Auth methods
///
/// To create an instance of the MSALNativeAuthPublicClientApplication use the clientId, tenantSubdomain, challengeTypes and redirectUri (optional)
/// to the initialiser method.
///
/// For example:
// TODO: change this comment
/// <pre>
///     do {
///         nativeAuth = try MSALNativeAuthPublicClientApplication(
///             clientId: "Enter_the_Application_Id_Here",
///             tenantSubdomain: "Enter_the_Tenant_Subdomain_Here",
///             challengeTypes: [.OOB]
///        )
///        print("Initialised Native Auth successfully.")
///     } catch {
///         print("Unable to initialize MSAL \(error)")
///     }
/// </pre>

@objcMembers
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    let controllerFactory: MSALNativeAuthControllerBuildable
    let inputValidator: MSALNativeAuthInputValidating

    private var cacheAccessorFactory: MSALNativeAuthCacheAccessorBuildable
    lazy var cacheAccessor: MSALNativeAuthCacheAccessor = {
        return cacheAccessorFactory.makeCacheAccessor(tokenCache: tokenCache, accountMetadataCache: accountMetadataCache)
    }()

    /// Initialize a MSALNativePublicClientApplication with a given configuration
    /// - Parameters:
    ///   - nativeAuthConfiguration: Configuration for native auth PublicClientApplication
    /// - Throws: An error that occurred creating the application object
    public init(nativeAuthConfiguration: MSALNativeAuthPublicClientApplicationConfig) throws {
        guard let ciamAuthority = nativeAuthConfiguration.authority as? MSALCIAMAuthority else {
            throw MSALNativeAuthInternalError.invalidAuthority
        }

        var internalConfig = try MSALNativeAuthInternalConfiguration(
            clientId: nativeAuthConfiguration.clientId,
            authority: ciamAuthority,
            challengeTypes: nativeAuthConfiguration.challengeTypes,
            capabilities: nativeAuthConfiguration.capabilities,
            redirectUri: nativeAuthConfiguration.redirectUri
        )
        internalConfig.sliceConfig = nativeAuthConfiguration.sliceConfig

        self.controllerFactory = MSALNativeAuthControllerFactory(config: internalConfig)
        self.cacheAccessorFactory = MSALNativeAuthCacheAccessorFactory()
        self.inputValidator = MSALNativeAuthInputValidator()

        if nativeAuthConfiguration.redirectUri == nil {
            MSALNativeAuthLogger.log(level: .warning, context: nil, format: MSALNativeAuthErrorMessage.redirectUriNotSetWarning)
            // we need to bypass redirect URI validation because we don't need a redirect URI for Native Auth scenarios
            nativeAuthConfiguration.bypassRedirectURIValidation = true
        }

        try super.init(configuration: nativeAuthConfiguration)
    }

    /// Initialize a MSALNativePublicClientApplication with a given configuration and challenge types
    /// - Parameters:
    ///   - config: Configuration for PublicClientApplication
    ///   - challengeTypes: The set of challenge types that this application can support as an ``MSALNativeAuthChallengeTypes`` optionset
    /// - Throws: An error that occurred creating the application object
    @available(*, deprecated, message: "Use init(nativeAuthConfiguration: ) instead.")
    public convenience init(
        configuration config: MSALPublicClientApplicationConfig,
        challengeTypes: MSALNativeAuthChallengeTypes) throws {
        guard let ciamAuthority = config.authority as? MSALCIAMAuthority else {
            throw MSALNativeAuthInternalError.invalidAuthority
        }
        let nativeAuthConfig = MSALNativeAuthPublicClientApplicationConfig(
            clientId: config.clientId,
            authority: ciamAuthority,
            challengeTypes: challengeTypes
        )
        nativeAuthConfig.redirectUri = config.redirectUri
        nativeAuthConfig.sliceConfig = config.sliceConfig
        nativeAuthConfig.bypassRedirectURIValidation = config.bypassRedirectURIValidation
        try self.init(nativeAuthConfiguration: nativeAuthConfig)
    }

    /// Initialize a MSALNativePublicClientApplication.
    /// - Parameters:
    ///   - clientId: The client ID of the application, this should come from the app developer portal.
    ///   - tenantSubdomain: The subdomain of the tenant, this should come from the app developer portal.
    ///   - challengeTypes: The set of challenge types that this application can support as an ``MSALNativeAuthChallengeTypes`` optionset
    ///   - redirectUri: Optional. The redirect URI for the application, this should come from the app developer portal.
    /// - Throws: An error that occurred creating the application object
    @available(*, deprecated, message: "Use init(nativeAuthConfiguration: ) instead.")
    public convenience init(
        clientId: String,
        tenantSubdomain: String,
        challengeTypes: MSALNativeAuthChallengeTypes,
        redirectUri: String? = nil) throws {
            let nativeAuthConfig = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: clientId,
                tenantSubdomain: tenantSubdomain,
                challengeTypes: challengeTypes
            )
            nativeAuthConfig.redirectUri = redirectUri
            try self.init(nativeAuthConfiguration: nativeAuthConfig)
    }

    init(
        controllerFactory: MSALNativeAuthControllerBuildable,
        cacheAccessorFactory: MSALNativeAuthCacheAccessorBuildable,
        inputValidator: MSALNativeAuthInputValidating,
        configuration: MSALPublicClientApplicationConfig
    ) {
        self.controllerFactory = controllerFactory
        self.cacheAccessorFactory = cacheAccessorFactory
        self.inputValidator = inputValidator

        super.init()
    }

    // MARK: delegate methods

    /// Sign up a user using parameters.
    /// - Parameters:
    ///   - parameters: Parameters used for the Sign Up flow.
    ///   - delegate: Delegate that receives callbacks for the Sign Up flow.
    public func signUp(
        parameters: MSALNativeAuthSignUpParameters,
        delegate: SignUpStartDelegate
    ) {
        Task {
            let controllerResponse = await signUpInternal(
                username: parameters.username,
                password: parameters.password,
                attributes: parameters.attributes,
                correlationId: parameters.correlationId
            )

            let delegateDispatcher = SignUpStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchSignUpCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength,
                    correlationId: controllerResponse.correlationId
                )
            case .attributesInvalid(let attributes):
                await delegateDispatcher.dispatchSignUpAttributesInvalid(attributeNames: attributes, correlationId: controllerResponse.correlationId)
            case .error(let error):
                await delegate.onSignUpStartError(error: error)
            }
        }
    }

    /// Sign in a user using parameters.
    /// - Parameters:
    ///   - parameters: Parameters used for the Sign In flow.
    ///   - delegate: Delegate that receives callbacks for the Sign In flow.
    public func signIn(
        parameters: MSALNativeAuthSignInParameters,
        delegate: SignInStartDelegate
    ) {
        Task {
            let claimsRequestJson = parameters.claimsRequest?.jsonString()
            let controllerResponse = await signInInternal(
                username: parameters.username,
                password: parameters.password,
                scopes: parameters.scopes,
                claimsRequestJson: claimsRequestJson,
                correlationId: parameters.correlationId
            )

            let delegateDispatcher = SignInStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchSignInCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength,
                    correlationId: controllerResponse.correlationId
                )
            case .passwordRequired(let newState):
                await delegateDispatcher.dispatchSignInPasswordRequired(newState: newState, correlationId: controllerResponse.correlationId)
            case .completed(let result):
                await delegateDispatcher.dispatchSignInCompleted(result: result, correlationId: controllerResponse.correlationId)
            case .error(let error):
                await delegate.onSignInStartError(error: error)
            case .awaitingMFA(let newState):
                await delegateDispatcher.dispatchAwaitingMFA(newState: newState, correlationId: controllerResponse.correlationId)
            case .jitAuthMethodsSelectionRequired(let authMethods, let newState):
                await delegateDispatcher.dispatchJITRequired(authMethods: authMethods,
                                                             newState: newState,
                                                             correlationId: controllerResponse.correlationId)
            }
        }
    }

    /// Reset the password using parameters
    /// - Parameters:
    ///   - parameters: Parameters used for the Reset Password flow.
    ///   - delegate: Delegate that receives callbacks for the Reset Password flow.
    public func resetPassword(
        parameters: MSALNativeAuthResetPasswordParameters,
        delegate: ResetPasswordStartDelegate
    ) {
        Task {
            let controllerResponse = await resetPasswordInternal(username: parameters.username,
                                                                 correlationId: parameters.correlationId)

            let delegateDispatcher = ResetPasswordStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchResetPasswordCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength,
                    correlationId: controllerResponse.correlationId
                )
            case .error(let error):
                await delegate.onResetPasswordStartError(error: error)
            }
        }
    }

    /// Retrieve the current signed in account from the cache.
    /// - Parameter correlationId: Optional. UUID to correlate this request with the server for debugging.
    /// - Returns: An object representing the account information if present in the local cache.
    public func getNativeAuthUserAccount(correlationId: UUID? = nil) -> MSALNativeAuthUserAccountResult? {
        let controller = controllerFactory.makeCredentialsController(cacheAccessor: cacheAccessor)
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        return controller.retrieveUserAccountResult(context: context)
    }
}
