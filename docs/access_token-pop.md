

# (Preview) MSAL Objc: Requesting Proof-of-Possession Access Tokens

1. **Need for Proof-of-Possession for Access Tokens****

   A standard access token from Azure Active Directory (AAD) is a Bearer token in JWT format corresponding to [RFC-7523](https://tools.ietf.org/html/rfc7523). These tokens can be used by anyone possessing the token to access the audience (`aud`) described in the JWT. Because a Bearer token may be used by anyone in possession of it, it is possible that malicious actors may replay tokens that have been leaked by resources or intercepted over the wire from break-and-inspect proxies against a resource to access protected systems or data.

   Proof of Possession (PoP) increases the security posture of these tokens embedding them inside of a JWT envelope and signing (binding) that JWT with RSA key material. The key material is generated on the device which was originally issued the tokens and never leaves it. The resulting JWT is called the Signed HTTP Request (SHR). This binding renders the access token unusable without a recent proof for the target resource endpoint.

2. **Basic Pop Token Flow.**

   ```
   +--------+                               +---------------+
   |        |--(A)- Authorization Request ->|   Resource    |
   |        |                               |     Owner     |
   |        |<-(B)-- Authorization Grant ---|               |
   |        |                               +---------------+
   |        |
   |        |                               +---------------+
   |        |--(C)-- Authorization Grant -->|               |
   | Client |       (resource, req_cnf)     | Authorization |
   |        |                               |     Server    |
   |        |<-(D)-- PoP Access Token ------|               |
   |        |       (rs_cnf, token_type)    +---------------+
   |        |        
   |        |                               +---------------+
   |        |--(E)-- PoP Access Token ----->|               |
   |        |   (with proof of private key) |    Resource   |
   |        |                               |     Server    |
   |        |<-(F)--- Protected Resource ---|               |
   +--------+                               +---------------+
   ```

   2.1	In the Token Request, the client sends an authorization grant, e.g., an authorization code or a refresh token, to the authorization server in order to obtain an access token (and potentially a refresh token). The client proves the possession of a private key belonging to some public key by first generating an asymmetric RSA key pair on the device. The client then sends an additional parameter "req_cnf" to the token endpoint which contains a thumbprint of the RSA public key the client would like to associate with the access token. Please refer to public key thumbprint computation spec here [https://tools.ietf.org/id/draft-ietf-oauth-pop-key-distribution-04.html]()

   2.2	The authorization server (AS) binds (sender-constrains) the access token to the public key claimed by the client; that is, the access token cannot be used without proving possession of the respective private key. This is signaled to the client by using the token_type value "pop" and by appending a "cnf" claim in the access token jwt containing a "kid" member identifying the public key.

   2.3	If the client wants to use the access token, it has to prove possession of the private key by adding a header to the request that, again, contains a JWT signed with this private key (**Signed Http Request**). The JWT contains the endpoint URL and the request method. The resource server needs to receive information about which public key to check against. This information is either encoded directly into the access token, for JWT structured access tokens, or provided at the token introspection endpoint of the authorization server (request not shown).

   2.4	 The resource server refuses to serve the request if the signature check fails or the data in the JWT do not match, e.g., the request URI does not match the URI claim in the JWT.

3. **Expiry time for Proof-of-Possession access tokens.**

   By default, Bearer access tokens issued by AAD have a 1 hour validity. The validity of the Signed HTTP Request may be shorter, depending on the resource middleware configuration.

   When a Signed Http Request (SHR) is created by the client, a timestamp (`ts`) claim is embedded in the JWT. The resource middleware will, upon receipt of the token, inspect its signature and timestamp to ensure integrity (anti-tamper protection) and validity (non-expiry). By default, the SAL middleware honors a 5 minute validity period meaning that once an SHR been signed by the client it may be used for 5 minutes before the resource will require a newly signed access token.

4. **How does Client -> Resource Provider protocol change between Bearer and Pop access tokens**.

   In the bearer flow, when a client requests a resource from an RP, the client provides an **authorization header** containing the AT. 

   In the PoP flow, when a client requests a resource from an RP, the client provides an authorization header containing the Signed Http Request**(SHR)**, which itself contains the AT: 

   |                               | **Bearer**            | **PoP**                |
   | ----------------------------- | --------------------- | ---------------------- |
   | **Authentication** **Method** | Bearer Authentication | PoP Authentication     |
   | **AT issued by STS**          | “Bearer” AT           | “PoP” AT               |
   | **Authorization Header**      | Bearer AT             | **SHR** **{ PoP AT }** |

5. **Configure MSAL to request Proof-of-Possession Access tokens.**

   5.1	For an interactive acquireToken request, create an instance of MSALInteractiveTokenParameters as shown below.

   **MSALInteractiveTokenParameters**

   ```objective-c
   #if TARGET_OS_IPHONE
       UIViewController *viewController = ...; // Pass a reference to the view controller that should be used when getting a token interactively
       MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:viewController];
   #else
       MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
   #endif 
   
   MSALInteractiveTokenParameters *interactiveParams = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes webviewParameters:webParameters];
   ```

   For a silent acquireToken request, create an instance of MSALSilentTokenParameters as shown below.

   **MSALSilentTokenParameters**

   ```
   NSError *error = nil;
   MSALAccount *account = [application accountForIdentifier:accountIdentifier error:&error];
   if (!account)
   {
       // handle error
       return;
   }
       
   MSALSilentTokenParameters *silentParams = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
   ```

   5.2	MSALTokenParameters which is the parent class for MSALInteractiveTokenParameters and MSALSilentTokenParameters has been extended to include an additional property called **authenticationScheme** as shown below.

   ```
   /**
    Authentication Scheme to access the resource
    */
   @property (nonatomic, nullable) id<MSALAuthenticationSchemeProtocol> authenticationScheme;
   ```

   Create an instance of authenticationScheme which is either MSALAuthenticationSchemeBearer or MSALAuthenticationSchemePop. MSALAuthenticationSchemeBearer is the default authentication scheme used by the library for bearer access tokens and does not require explicit declaration.

   MSALAuthenticationSchemePop has two required parameters. 

   | Parameter Name       | Parameter Type | Parameter Description          | Required |
   | -------------------- | -------------- | ------------------------------ | -------- |
   | httpMethod           | MSALHttpMethod | Http method for the request    | Yes      |
   | requestUrl           | NSURL          | Request url for pop resource   | Yes      |
   | nonce                | NSString       | Unique NSUUID string           | No       |
   | additionalParameters | NSDictionary   | Reserved for future parameters | No       |

   MSALHttpMethod is of type NS_Enum and can take one of the following values:

   ```objective-c
   typedef NS_ENUM(NSUInteger, MSALHttpMethod)
   {
       /*
           Http Method for the pop resource
       */
       MSALHttpMethodGET,
       MSALHttpMethodHEAD,
       MSALHttpMethodPOST,
       MSALHttpMethodPUT,
       MSALHttpMethodDELETE,
       MSALHttpMethodCONNECT,
       MSALHttpMethodOPTIONS,
       MSALHttpMethodTRACE,
       MSALHttpMethodPATCH
       
   };
   ```

   

   Create an instance of MSALAuthenticationSchemePop as shown below:

   ```objective-c
   MSALAuthenticationSchemePop *authScheme = [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];
   ```

   

   5.3	Assign the authenticatioScheme initialized in the **step 5.2** above to authenticationScheme property of MSALInteractiveTokenParameters (interactiveParams) / MSALSilentTokenParameters (silentParams) object initialized in **step 5.1** as shown below. 

   **Note:** This step is only required if you need to set the authentication scheme to MSALAuthenticationSchemePop. The default authenticationScheme property of MSALTokenParameters is set to MSALAuthenticationSchemeBearer in the initializer as shown below.

   ```objective-c
   @implementation MSALTokenParameters
   
   - (instancetype)initWithScopes:(NSArray<NSString *> *)scopes
   {
       self = [super init];
       if (self)
       {
           _scopes = scopes;
           _authenticationScheme = [MSALAuthenticationSchemeBearer new];
       }
       
       return self;
   }
   ```

   ```objective-c
   interactiveParams.authenticationScheme = authScheme
   silentParams.authenticationScheme = authScheme
   ```

   5.4	**Get the Signed Http Request (SHR) which is sent to the Resource Provider (RP) to access the pop protected resource.**

   MSALResult has been extended to include two additional properties as shown below. For pop protected resource, the accessToken property returns the Signed Http Request minus the scheme prefix (Pop).

   ```
   /**
    The authorization header for the specific authentication scheme . For instance "Bearer ..." or "Pop ...". For pop resource, this value is the Signed Http Request (SHR) as explained in step 4 which is sent to the resource provided to access the resource
    */
   @property (readonly, nonnull) NSString *authorizationHeader;
   
   /**
    The authentication scheme for the tokens issued. For instance "Bearer " or "Pop".
    */
   @property (readonly, nonnull) NSString *authenticationScheme;
   ```

6. **Does MSAL still supports Bearer access token flows.**

   Yes! PoP and Bearer flows may be used interchangeably with MSAL and with supported Authenticator versions **as long as the targeted resource supports it**.

7. **MSAL / Authenticator versions which support Proof-of-Possession access tokens.**

   7.1	MSAL  - **1.1.6**

   7.2	Authenticator - **6.4.22**

8. **References**

   8.1	JSON Web Tokens - [RFC-7523](https://tools.ietf.org/html/rfc7523)

   8.2	A Method for Signing HTTP Requests for OAuth - [OAuth Working Group Draft](https://tools.ietf.org/html/draft-ietf-oauth-signed-http-request-03)

   8.3	Proof-of-Possession Key Semantics for JSON Web Tokens (JWTs) - [https://tools.ietf.org/html/rfc7800]()

   

   