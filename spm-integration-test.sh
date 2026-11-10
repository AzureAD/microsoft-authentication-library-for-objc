BRANCH_NAME="$1"
INCLUDE_VISIONOS=false
SKIP_SAMPLE_APP=false

# Parse optional flags
for arg in "$@"; do
  case $arg in
    --include-visionos)
      INCLUDE_VISIONOS=true
      ;;
    --skip-sample-app)
      SKIP_SAMPLE_APP=true
      ;;
  esac
done

SAMPLE_APP_TEMP_DIR="NativeAuthSampleAppTemp"
current_date=$(date +"%Y-%m-%d %H:%M:%S")

set -e

# Build framework

echo "Building framework"

xcodebuild -sdk iphonesimulator -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -archivePath archive/iOSSimulator CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
xcodebuild -sdk iphoneos -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -archivePath archive/iOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
xcodebuild -sdk macosx -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (Mac Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -archivePath archive/macOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1

# -debug-symbols requires absolute paths; positional arguments preserve spaces under sh.
ARCHIVE_ROOT="$(pwd)/archive"
EXPECTED_SLICES=3
set -- \
  -framework "$ARCHIVE_ROOT/iOSSimulator.xcarchive/Products/Library/Frameworks/MSAL.framework" \
  -debug-symbols "$ARCHIVE_ROOT/iOSSimulator.xcarchive/dSYMs/MSAL.framework.dSYM" \
  -framework "$ARCHIVE_ROOT/iOS.xcarchive/Products/Library/Frameworks/MSAL.framework" \
  -debug-symbols "$ARCHIVE_ROOT/iOS.xcarchive/dSYMs/MSAL.framework.dSYM" \
  -framework "$ARCHIVE_ROOT/macOS.xcarchive/Products/Library/Frameworks/MSAL.framework" \
  -debug-symbols "$ARCHIVE_ROOT/macOS.xcarchive/dSYMs/MSAL.framework.dSYM"

if [ "$INCLUDE_VISIONOS" = true ]; then
  echo "Including visionOS in xcframework"
  xcodebuild -sdk xrsimulator -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -archivePath archive/visionOSSimulator CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
  xcodebuild -sdk xros -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -archivePath archive/visionOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
  EXPECTED_SLICES=5
  set -- "$@" \
    -framework "$ARCHIVE_ROOT/visionOSSimulator.xcarchive/Products/Library/Frameworks/MSAL.framework" \
    -debug-symbols "$ARCHIVE_ROOT/visionOSSimulator.xcarchive/dSYMs/MSAL.framework.dSYM" \
    -framework "$ARCHIVE_ROOT/visionOS.xcarchive/Products/Library/Frameworks/MSAL.framework" \
    -debug-symbols "$ARCHIVE_ROOT/visionOS.xcarchive/dSYMs/MSAL.framework.dSYM"
else
  echo "Skipping visionOS (use --include-visionos to include)"
fi

xcodebuild -create-xcframework "$@" -output framework/MSAL.xcframework > build.log 2>&1

python3 scripts/validate_xcframework_dsyms.py framework/MSAL.xcframework --expected-slices "$EXPECTED_SLICES"

echo "Creating MSAL.zip"
zip -r MSAL.zip framework/MSAL.xcframework -y -v

echo "Calculating checksum"
CHECKSUM=$(swift package compute-checksum MSAL.zip)
if [ -z "$CHECKSUM" ]; then
  echo "** Checksum could not be obtained **"
  exit 1
fi

echo "Updating Package.swift"

NEW_URL="https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/$BRANCH_NAME/MSAL.zip"

sed -i '' "s#url: \"[^\"]*\"#url: \"$NEW_URL\"#" Package.swift
sed -i '' "s#checksum: \"[^\"]*\"#checksum: \"$CHECKSUM\"#" Package.swift

echo "Pushing MSAL.zip and Package.swift to $BRANCH_NAME"

git add MSAL.zip Package.swift

authorName=$(git log -1 --pretty=format:'%an')
authorEmail=$(git log -1 --pretty=format:'%ae')
git config user.email "${authorEmail}"
git config user.name "${authorName}"
author=$(git log -1 --pretty=format:'%an <%ae>')
git commit -m "Publish temporary Swift Package $current_date" -q --author="${author}"
git push -f origin "$BRANCH_NAME"

# Download and build Sample App (validates SPM package works end-to-end)

if [ "$SKIP_SAMPLE_APP" = true ]; then
  echo "Skipping sample app build (--skip-sample-app flag set)"
  echo "xcframework and Package.swift validation complete"
else
  echo "Downloading and updating Sample App to use temporary Swift Package"

  mkdir -p "$SAMPLE_APP_TEMP_DIR"
  cd "$SAMPLE_APP_TEMP_DIR"

  git clone https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample.git
  cd ms-identity-ciam-native-auth-ios-sample

  sed -i '' 's#kind = upToNextMajorVersion;#kind = branch;#' NativeAuthSampleApp.xcodeproj/project.pbxproj
  sed -i '' "s#minimumVersion = [0-9.]*;#branch = $BRANCH_NAME;#" NativeAuthSampleApp.xcodeproj/project.pbxproj

  rm -f NativeAuthSampleApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

  echo "Running the Sample App with the temporary Swift Package"

  xcodebuild -resolvePackageDependencies
  xcodebuild -scheme NativeAuthSampleApp -configuration Release -sdk iphonesimulator -destination "platform=iOS Simulator,name=${IOS_SIM_DEVICE:-iPhone 17},OS=${IOS_SIM_OS:-26.1}" clean build
fi