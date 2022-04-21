#!/bin/sh

# Copyright 2018-2019 Yubico AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This build script outputs the binary distribution of YubiKit:
# - The release output is /releases/YubiKit
# - The library flavours (release, debug_universal, etc.) are generated in /releases/YubiKit/YubiKit
# - The demo application is copied as part of the binary release in /releases/YubiKit/YubiKitDemo
# - Additional assets, including the documentation and licence are copied in releases/YubiKit

FRAMEWORK=YubiKit
LIBNAME=libYubiKit.a

# The temporary build output. The build flavours will be moved in /releases/YubiKit/YubiKit
BUILD_OUTPUT=build

DEBUG_OUTPUT=debug
DEBUG_BUILD=$BUILD_OUTPUT/$DEBUG_OUTPUT

RELEASE_OUTPUT=release
RELEASE_BUILD=$BUILD_OUTPUT/$RELEASE_OUTPUT

DEBUG_UNIVERSAL_OUTPUT=debug_universal
DEBUG_UNIVERSAL_BUILD=$BUILD_OUTPUT/$DEBUG_UNIVERSAL_OUTPUT

RELEASE_UNIVERSAL_OUTPUT=release_universal
RELEASE_UNIVERSAL_BUILD=$BUILD_OUTPUT/$RELEASE_UNIVERSAL_OUTPUT

LIBRARY_RELEASES=releases

# Remove the old build if any
rm -Rf $BUILD_OUTPUT

# Build Debug Universal (ARM + Intel)

xcodebuild build \
    ARCHS="arm64" \
    -project $FRAMEWORK.xcodeproj \
    -target $FRAMEWORK \
    -sdk iphoneos \
    ONLY_ACTIVE_ARCH=NO \
    -configuration Debug \
    -destination "generic/platform=iOS" \
    SYMROOT=$DEBUG_BUILD

xcodebuild build \
    ARCHS="x86_64" \
    -project $FRAMEWORK.xcodeproj \
    -target $FRAMEWORK \
    -sdk iphonesimulator \
    ONLY_ACTIVE_ARCH=NO \
    -configuration Debug \
    SYMROOT=$DEBUG_BUILD

cp -RL $DEBUG_BUILD/Debug-iphoneos $DEBUG_UNIVERSAL_BUILD

lipo -create \
    $DEBUG_BUILD/Debug-iphoneos/$LIBNAME \
    $DEBUG_BUILD/Debug-iphonesimulator/$LIBNAME \
    -output $DEBUG_UNIVERSAL_BUILD/$LIBNAME

# Build Release

xcodebuild archive \
    ARCHS="arm64" \
    -project $FRAMEWORK.xcodeproj \
    -scheme $FRAMEWORK \
    -sdk iphoneos \
    ONLY_ACTIVE_ARCH=NO \
    -destination "generic/platform=iOS" \
    SYMROOT=$RELEASE_BUILD

xcodebuild build \
    ARCHS="x86_64" \
    -project $FRAMEWORK.xcodeproj \
    -target $FRAMEWORK \
    -sdk iphonesimulator \
    ONLY_ACTIVE_ARCH=NO \
    -configuration Release \
    SYMROOT=$RELEASE_BUILD

# ARM Release
cp -RL $RELEASE_BUILD/Release-iphoneos/$LIBNAME $RELEASE_BUILD

# Universal Release
cp -RL $RELEASE_BUILD/Release-iphoneos $RELEASE_UNIVERSAL_BUILD

lipo -create \
    $RELEASE_BUILD/Release-iphonesimulator/$LIBNAME \
    $RELEASE_BUILD/Release-iphoneos/$LIBNAME \
    -output $RELEASE_UNIVERSAL_BUILD/$LIBNAME

# Package

rm -Rf $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK
mkdir -p $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK

cp -RL $DEBUG_UNIVERSAL_BUILD/include $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK

mkdir -p $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK/debug_universal
cp -RL $DEBUG_UNIVERSAL_BUILD/$LIBNAME $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK/debug_universal

mkdir -p $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK/release
cp -RL $RELEASE_BUILD/$LIBNAME $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK/release

mkdir -p $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK/release_universal
cp -RL $RELEASE_UNIVERSAL_BUILD/$LIBNAME $LIBRARY_RELEASES/$FRAMEWORK/$FRAMEWORK/release_universal

cp -RL ../YubiKitDemo $LIBRARY_RELEASES/$FRAMEWORK

# Copy license

cp -RL ../LICENSE $LIBRARY_RELEASES/$FRAMEWORK

# Copy documentation

cp -RL ../README.md $LIBRARY_RELEASES/$FRAMEWORK
cp -RL ../Changelog.md $LIBRARY_RELEASES/$FRAMEWORK
cp -RL ../docassets $LIBRARY_RELEASES/$FRAMEWORK

# Remove the temporary build output
rm -Rf $BUILD_OUTPUT
