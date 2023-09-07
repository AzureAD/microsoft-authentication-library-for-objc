# MSAL Native Auth Sample App Private Preview

This is a sample application used to demonstrate the CIAM extension of the MSAL framework that is currently in private preview. It incorporates private extensions of the [MSAL Native Auth iOS](https://github.com/AzureAD/msal-objc-native-auth-preview) and [MSAL IdentityCore](https://github.com/AzureAD/msal-common-for-objc-native-auth-preview) libraries. 

Questions, issues, or feedback can be directed to idnadevexciamdublin@microsoft.com

## Prerequisite

To install and run the sample application is required a Mac with Xcode installed.

## Setup
After you have downloaded the code or cloned the repo, you need to initialise the git submodule. 
To do that open the command line and navigate the home directory of the project just downloaded. Now run this command:

```
git submodule update --init
```

At this point you can navigate to the sample app folder: Samples/ios-native-auth-simple/NativeAuthSampleApp and open the project using Xcode

After that, you will be able to run the sample application.

## Running the application
This project is still a work in progress, and is not ready for consumption yet. 
For a temporary version that uses mocked responses, please checkout branch `mocked-responses`.
