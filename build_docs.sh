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
cp README.md docs.temp/
cd docs.temp
echo -e "Generating MSAL documentation"
jazzy --objc --umbrella-header MSAL/MSAL.h --framework-root . --sdk iphonesimulator --author Microsoft\ Corporation --author_url https://aka.ms/azuread  --github_url https://github.com/AzureAD/microsoft-authentication-library-for-objc --theme fullwidth

