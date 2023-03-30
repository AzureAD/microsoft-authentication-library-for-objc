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

public enum ChallengeType {
    case oob
    case password
}

@objcMembers
public class MSALNativeError: LocalizedError {
    private let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

@objcMembers
public class SignUpError: MSALNativeError {
    let type: SignUpErrorType

    init(type: SignUpErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }
}

@objcMembers
public class VerifyCodeError: MSALNativeError {
    let type: VerifyCodeErrorType

    init(type: VerifyCodeErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }
}

@objcMembers
public class PasswordRequiredError: MSALNativeError {
    let type: PasswordRequiredErrorType

    init(type: PasswordRequiredErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }
}

@objcMembers
public class AttributeRequiredError: MSALNativeError {
    let type: AttributeRequiredErrorType

    init(type: AttributeRequiredErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }
}

//TODO: is this a good name?
@objc
public enum SignUpErrorType: Int {
    case userExists
    case passwordInvalid
    case invalidAttributes
    case generalError
}

@objc
public enum VerifyCodeErrorType: Int {
    case generalError
    case invalidOOB
    case tooManyOOB
}

@objc
public enum PasswordRequiredErrorType: Int {
    case generalError
    case invalidPassword
}

@objc
public enum AttributeRequiredErrorType: Int {
    case generalError
    case invalidAttribute
}

public protocol SignUpDelegate {
    func onOOBSent(flow: OOBSentFlow)
    func onError(error: SignUpError)
    func onRedirect()
}

public protocol VerifyCodeDelegate {
    //TODO: what should we return here? SLT?
    func completed()
    //TODO: do we need the state for the error? can the ext dev use the existing flow instance?
    func onError(error: VerifyCodeError, state: OOBSentFlow?)
    func onRedirect()
    func passwordRequired(flow: PasswordRequiredFlow)
    func attributesRequired(flow: AttributeRequiredFlow)
}

public protocol PasswordRequiredDelegate {
    func completed()
    //TODO: do we need the state for the error? can the ext dev use the existing flow instance?
    func onError(error: PasswordRequiredError, state: PasswordRequiredFlow?)
    // TODO: exception
    func onRedirect()
    func attributesRequired(flow: AttributeRequiredFlow)
}

public protocol AttributeRequiredDelegate {
    func completed()
    //TODO: do we need the state for the error? can the ext dev use the existing flow instance?
    func onError(error: AttributeRequiredError, state: AttributeRequiredFlow?)
    //TODO: do we need this method for passwordRequired?
    func onRedirect()
}

//TODO: create super class
@objcMembers
public class OOBSentFlow {
    private let credentialToken: String

    init(credentialToken: String) {
        self.credentialToken = credentialToken
    }

    // TODO: we need a delegate to manage unexpected errors, maybe we need a new delegate to manage less errors than signIn and not redirect
    public func resendCode(delegate: SignUpDelegate, correlationId: UUID? = nil) {
        delegate.onOOBSent(flow: self)
    }

    public func verifyCode(otp: String, callback: VerifyCodeDelegate, correlationId: UUID? = nil) {
        callback.completed()
    }
}

@objcMembers
public class PasswordRequiredFlow {
    private let credentialToken: String

    init(credentialToken: String) {
        self.credentialToken = credentialToken
    }

    public func setPassword(password: String, callback: PasswordRequiredDelegate, correlationId: UUID? = nil) {
        
    }
}

@objcMembers
public class AttributeRequiredFlow {
    private let credentialToken: String

    init(credentialToken: String) {
        self.credentialToken = credentialToken
    }

    public func setAttributes(attributes: [String: Any], callback: AttributeRequiredDelegate, correlationId: UUID? = nil) {
        
    }
}

@objcMembers
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    private let controllerFactory: MSALNativeAuthRequestControllerBuildable
    private let inputValidator: MSALNativeAuthInputValidating

    public override init(configuration config: MSALPublicClientApplicationConfig) throws {
        guard let aadAuthority = config.authority as? MSALAADAuthority else {
            throw MSALNativeAuthError.invalidAuthority
        }

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: config.clientId,
            authority: aadAuthority
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        try super.init(configuration: config)
    }

    public init(clientId: String, challengeTypes: [ChallengeType], rawTenant: String? = nil, redirectUri: String? = nil) throws {
        let aadAuthority = try MSALNativeAuthAuthorityProvider()
            .authority(rawTenant: rawTenant)

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: clientId,
            authority: aadAuthority,
            rawTenant: rawTenant
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        let configuration = MSALPublicClientApplicationConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            authority: aadAuthority
        )

        try super.init(configuration: configuration)
    }

    init(
        controllerFactory: MSALNativeAuthRequestControllerBuildable,
        inputValidator: MSALNativeAuthInputValidating
    ) {
        self.controllerFactory = controllerFactory
        self.inputValidator = inputValidator

        super.init()
    }
    
    // MARK: new methods
    
    public func signUp(email: String, password: String?, attributes: [String: Any], correlationId: UUID?, callback: SignUpDelegate) {
        callback.onError(error: SignUpError(type: SignUpErrorType.userExists))
    }
    
    public func signIn(email: String, password: String?, correlationId: UUID?, callback: SignInStartDelegate) {
        callback.onError(error: SignInStartError(type: SignInStartErrorType.userNotFound))
    }
    
    public func resetPassword(email: String, correlationId: UUID?, callback: ResetPasswordStartDelegate) {
        
    }
    
    public func getUserAccount(completion: @escaping (MSALNativeAuthUserAccount, Error) -> Void) {

    }
}
