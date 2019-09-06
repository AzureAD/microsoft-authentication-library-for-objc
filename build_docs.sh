#!/bin/bash

if [ "$TRAVIS_BRANCH" == "reference-docs" ] && [ "$TRAVIS_PULL_REQUEST" == "false" ]
then
  gem install jazzy
  echo -e "Copying MSAL public files"
  mkdir docs.temp
  mkdir docs.temp/MSAL
  cp `find MSAL/src/public` docs.temp/MSAL
  cd docs.temp
  echo -e "Generating MSAL documentation"
  jazzy --objc --umbrella-header MSAL/MSAL.h --framework-root . --sdk iphonesimulator
fi
