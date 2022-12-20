# Introduction

The goal of the sample app is to show how to use the ClientAuth SDK. 

# Getting Started

1. Clone the repo
2. Open `SDKSampleApp.xcodeproj`.
3. Select as target any iOS device and run the project.

The sample app Xcode project references the MSAL SDK project directly from the same repo so there is no need to fetch dependencies before building.

# Structure

These are the main parts of the project:

## SDK related files

The files containing the SDK are inside the folder `ClientAuthSDKCommunicator`:

- `IClientAuthSDKCommunicator`: an interface that mimics the API from the ClientAuth SDK POC.
- `ClientAuthSDKCommunicator`: the implementation of `IClientAuthSDKCommunicator`. This class is:
    - A mock for all flows as they are not connected to ClientAuth SDK POC.

These two files are expected to be removed once the implementation of the new SDK (MSAL CIAM SDK) is ready.

## Shared UI screens

The following ViewControllers are shared across the project:

- InitialViewController: Any of the authentication flows can be launched from here.
- LoggedInViewController: Each of the authentication flows ends in this screen. It shows the user's email and access token.

## Authentication Flows

The sample app is composed by the following authentication flows:

- Sign up with email and password + email verification
- Login with email and password
- Passwordless with email OTP (the UI is the same for both sign in and sign up)
- Reset password (via email OTP)

Each authentication flow has its own folder, and consists of one or more ViewController and a Storyboard file.

## Utility Files

These classes provide utility functions to avoid writing boilerplate code for each ViewController.
