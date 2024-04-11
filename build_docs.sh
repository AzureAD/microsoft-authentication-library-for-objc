#!/bin/bash
# To build manually run "sudo sh build_docs.sh"
# As MSAL is a mixed Objective-C and Swift project we need to use SourceKitten to
# first extract the doc comments from the source before building with Jazzy. For more
# details see https://github.com/realm/jazzy?tab=readme-ov-file#mixed-objective-c--swift
gem install jazzy
echo -e "Copying MSAL public files"
mkdir docs.temp
mkdir docs.temp/MSAL
cp `find MSAL/src/public` docs.temp/MSAL
cp `find MSAL/src/native_auth/public` docs.temp/MSAL
cp README.md docs.temp/

echo -e "Generating MSAL documentation"
# Generate Swift SourceKitten output
sourcekitten doc -- -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" -configuration Debug RUN_CLANG_STATIC_ANALYZER=NO -sdk iphonesimulator CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.4' > docs.temp/swiftDoc.json

# Generate Objective-C SourceKitten output
cd docs.temp
sourcekitten doc --objc $(pwd)/MSAL/MSAL.h -- -x objective-c  -isysroot $(xcrun --show-sdk-path --sdk iphonesimulator) \-I $(pwd) -fmodules > objcDoc.json
cd ..

# Feed both outputs to Jazzy as a comma-separated list
jazzy --module MSAL --sourcekitten-sourcefile docs.temp/swiftDoc.json,docs.temp/objcDoc.json --author Microsoft\ Corporation --author_url https://aka.ms/azuread --github_url https://github.com/AzureAD/microsoft-authentication-library-for-objc --theme fullwidth --output docs.temp/docs
