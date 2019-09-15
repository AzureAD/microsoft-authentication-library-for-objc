#!/bin/bash

if [ "$TRAVIS_BRANCH" == "master" ] && [ "$TRAVIS_PULL_REQUEST" == "false" ]
then
  gem install jazzy
  echo -e "Copying MSAL public files"
  mkdir docs.temp
  mkdir docs.temp/MSAL
  cp `find MSAL/src/public` docs.temp/MSAL
  cp README.md docs.temp/
  cd docs.temp
  echo -e "Generating MSAL documentation"
  jazzy --objc --umbrella-header MSAL/MSAL.h --framework-root . --sdk iphonesimulator --author Microsoft\ Corporation --author_url https://aka.ms/azuread  --github_url https://github.com/AzureAD/microsoft-authentication-library-for-objc --theme fullwidth
fi
