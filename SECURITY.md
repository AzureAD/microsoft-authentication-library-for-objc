# Security Policy

Hello Team, we are getting a  `Hardcoded cryptographic keys` security exception and [Microsoft.Security](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5390) also encourages considering re-designing the application to fix this [Weakness](https://cwe.mitre.org/data/definitions/321.html).

Propagation: Pods/MSAL/MSAL/IdentityCore/IdentityCore/src/util/**NSData+AES.m**
`CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
key, keySize,
NULL /* initialization vector (optional) */,
[self bytes], dataLength, /* input */
buffer, bufferSize, /* output */
&numBytesDecrypted);`

Source: Pods/MSAL/MSAL/IdentityCore/IdentityCore/src/requests/broker/**MSIDBrokerCryptoProvider.m** at line 109
`(NSData *) msidAES128DecryptedDataWithKey:(const void *) keySize:(size_t)
CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
key, keySize,
NULL /* initialization vector (optional) */,
[self bytes], dataLength, /* input */
buffer, bufferSize, /* output */
&numBytesDecrypted);`

### Questions:

1.  Is this really a matter of concern to use MSAL library with this weakness?
2. What could be the fix for this weakness?
3. How soon we can expect a fix?
