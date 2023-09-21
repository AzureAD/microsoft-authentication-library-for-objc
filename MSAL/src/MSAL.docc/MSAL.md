# ``MSAL``

The MSAL Native Auth SDK allows developers to add authentication to an app using native UI.

## Overview

MSAL Native Auth is built on top of the MSAL Objective-C SDK so this reference documentation includes the full reference documentation for all MSAL classes.

The first step is to create and configure a ``MSALNativeAuthPublicClientApplication`` by calling the  ``MSALNativeAuthPublicClientApplication/init(clientId:challengeTypes:rawTenant:redirectUri:)`` method with valid values.


## Topics

### Configuring an application

### Native Auth methods
- ``MSALNativeAuthPublicClientApplication/signIn(username:scopes:correlationId:delegate:)``
- ``MSALNativeAuthPublicClientApplication/signInUsingPassword(username:password:scopes:correlationId:delegate:)``

- ``MSALNativeAuthPublicClientApplication/signUp(username:attributes:correlationId:delegate:)``
- ``MSALNativeAuthPublicClientApplication/signUpUsingPassword(username:password:attributes:correlationId:delegate:)``

- ``MSALNativeAuthPublicClientApplication/resetPassword(username:correlationId:delegate:)``

- ``MSALNativeAuthPublicClientApplication/getNativeAuthUserAccount(correlationId:)``


