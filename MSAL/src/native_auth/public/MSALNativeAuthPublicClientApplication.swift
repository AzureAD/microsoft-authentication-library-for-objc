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

@objcMembers
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    let controllerFactory: MSALNativeAuthControllerBuildable
    let inputValidator: MSALNativeAuthInputValidating
    private let internalChallengeTypes: [MSALNativeAuthInternalChallengeType]

    /// Initialize a MSALNativePublicClientApplication with a given configuration and challenge types
    /// - Parameters:
    ///   - config: Configuration for PublicClientApplication
    ///   - challengeTypes: The set of capabilities that this application can support as an ``MSALNativeAuthChallengeTypes`` optionset
    /// - Throws: An error that occurred creating the application object
    public init(
        configuration config: MSALPublicClientApplicationConfig,
        challengeTypes: MSALNativeAuthChallengeTypes) throws {
        guard let ciamAuthority = config.authority as? MSALCIAMAuthority else {
            throw MSALNativeAuthInternalError.invalidAuthority
        }

        self.internalChallengeTypes =
            MSALNativeAuthPublicClientApplication.getInternalChallengeTypes(challengeTypes)

        var nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: config.clientId,
            authority: ciamAuthority,
            challengeTypes: internalChallengeTypes
        )
        nativeConfiguration.sliceConfig = config.sliceConfig

        self.controllerFactory = MSALNativeAuthControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        try super.init(configuration: config)
    }

    /// Initialize a MSALNativePublicClientApplication.
    /// - Parameters:
    ///   - clientId: The client ID of the application, this should come from the app developer portal.
    ///   - tenantSubdomain: The subdomain of the tenant, this should come from the app developer portal.
    ///   - challengeTypes: The set of capabilities that this application can support as an ``MSALNativeAuthChallengeTypes`` optionset
    ///   - redirectUri: Optional. The redirect URI for the application, this should come from the app developer portal. 
    /// - Throws: An error that occurred creating the application object
    public init(
        clientId: String,
        tenantSubdomain: String,
        challengeTypes: MSALNativeAuthChallengeTypes,
        redirectUri: String? = nil) throws {
        let ciamAuthority = try MSALNativeAuthAuthorityProvider()
                .authority(rawTenant: tenantSubdomain)

        self.internalChallengeTypes = MSALNativeAuthPublicClientApplication.getInternalChallengeTypes(challengeTypes)
        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: clientId,
            authority: ciamAuthority,
            challengeTypes: internalChallengeTypes
        )

        self.controllerFactory = MSALNativeAuthControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        let configuration = MSALPublicClientApplicationConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            authority: ciamAuthority
        )

        // we need to bypass redirect URI validation because we don't need a redirect URI for Native Auth scenarios
        configuration.bypassRedirectURIValidation = redirectUri == nil
        let defaultRedirectUri = String(format: "msauth.%@://auth", Bundle.main.bundleIdentifier ?? "<bundle_id>")
        // we need to set a default redirect URI value to ensure IdentityCore checks the bypassRedirectURIValidation flag
        configuration.redirectUri = redirectUri ?? defaultRedirectUri

        try super.init(configuration: configuration)
    }

    init(
        controllerFactory: MSALNativeAuthControllerBuildable,
        inputValidator: MSALNativeAuthInputValidating,
        internalChallengeTypes: [MSALNativeAuthInternalChallengeType]
    ) {
        self.controllerFactory = controllerFactory
        self.inputValidator = inputValidator
        self.internalChallengeTypes = internalChallengeTypes

        super.init()
    }

    // MARK: delegate methods

    /// Sign up a user with a given username and password.
    /// - Parameters:
    ///   - username: Username for the new account.
    ///   - password: Password to be used for the new account.
    ///   - attributes: Optional. User attributes to be used during account creation.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Sign Up flow.
    public func signUpUsingPassword(
        username: String,
        password: String,
        attributes: [String: Any]? = nil,
        correlationId: UUID? = nil,
        delegate: SignUpPasswordStartDelegate
    ) {
        Task {
            let controllerResponse = await signUpUsingPasswordInternal(
                username: username,
                password: password,
                attributes: attributes,
                correlationId: correlationId
            )

            let delegateDispatcher = SignUpPasswordStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchSignUpPasswordCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength
                )
            case .attributesInvalid(let attributes):
                await delegateDispatcher.dispatchSignUpAttributesInvalid(attributeNames: attributes)
            case .error(let error):
                await delegate.onSignUpPasswordStartError(error: error)
            }
        }
    }

    /// Sign up a user with a given username.
    /// - Parameters:
    ///   - username: Username for the new account.
    ///   - attributes: Optional. User attributes to be used during account creation.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Sign Up flow.
    public func signUp(
        username: String,
        attributes: [String: Any]? = nil,
        correlationId: UUID? = nil,
        delegate: SignUpStartDelegate
    ) {
        Task {
            let controllerResponse = await signUpInternal(username: username, attributes: attributes, correlationId: correlationId)
            let delegateDispatcher = SignUpStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchSignUpCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength
                )
            case .attributesInvalid(let attributes):
                await delegateDispatcher.dispatchSignUpAttributesInvalid(attributeNames: attributes)
            case .error(let error):
                await delegate.onSignUpStartError(error: error)
            }
        }
    }

    /// Sign in a user with a given username and password.
    /// - Parameters:
    ///   - username: Username for the account.
    ///   - password: Password for the account.
    ///   - scopes: Optional. Permissions you want included in the access token received after sign in flow has completed.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Sign In flow.
    public func signInUsingPassword(
        username: String,
        password: String,
        scopes: [String]? = nil,
        correlationId: UUID? = nil,
        delegate: SignInPasswordStartDelegate
    ) {
        Task {
            let controllerResponse = await signInUsingPasswordInternal(
                username: username,
                password: password,
                scopes: scopes,
                correlationId: correlationId
            )

            let delegateDispatcher = SignInPasswordStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .completed(let result):
                await delegateDispatcher.dispatchSignInCompleted(result: result)
            case .codeRequired(let newState, let sentTo, let channelType, let codeLength):
                await delegateDispatcher.dispatchSignInCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelType,
                    codeLength: codeLength
                )
            case .error(let error):
                await delegate.onSignInPasswordStartError(error: error)
            }
        }
    }

    /// Sign in a user with a given username.
    /// - Parameters:
    ///   - username: Username for the account
    ///   - scopes: Optional. Permissions you want included in the access token received after sign in flow has completed.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Sign In flow.
    public func signIn(
        username: String,
        scopes: [String]? = nil,
        correlationId: UUID? = nil,
        delegate: SignInStartDelegate
    ) {
        Task {
            let controllerResponse = await signInInternal(
                username: username,
                scopes: scopes,
                correlationId: correlationId
            )

            let delegateDispatcher = SignInStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchSignInCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength
                )
            case .passwordRequired(let newState):
                await delegateDispatcher.dispatchSignInPasswordRequired(newState: newState)
            case .error(let error):
                await delegate.onSignInStartError(error: error)
            }
        }
    }

    /// Reset the password for a given username.
    /// - Parameters:
    ///   - username: Username for the account.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Reset Password flow.
    public func resetPassword(
        username: String,
        correlationId: UUID? = nil,
        delegate: ResetPasswordStartDelegate
    ) {
        Task {
            let controllerResponse = await resetPasswordInternal(username: username, correlationId: correlationId)
            let delegateDispatcher = ResetPasswordStartDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchResetPasswordCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength
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
        let controller = controllerFactory.makeCredentialsController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        return controller.retrieveUserAccountResult(context: context)
    }
}
