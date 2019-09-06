#!/bin/bash

echo -e "Copying MSAL public files"
mkdir docs.temp
mkdir docs.temp/MSAL
cp `find MSAL/src/public` docs.temp/MSAL
cd docs.temp
jazzy --objc --umbrella-header MSAL/MSAL.h --framework-root . --sdk iphonesimulator
