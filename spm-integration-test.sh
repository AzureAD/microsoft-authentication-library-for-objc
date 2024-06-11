BRANCH_NAME="$1"
SAMPLE_APP_TEMP_DIR="NativeAuthSampleAppTemp"
current_date=$(date +"%Y-%m-%d %H:%M:%S")

set -e

# Build framework

echo "Building framework"

xcodebuild -sdk iphonesimulator -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/iOSSimulator CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
xcodebuild -sdk iphoneos -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/iOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
xcodebuild -sdk macosx -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (Mac Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/macOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1

xcodebuild -create-xcframework -framework archive/iOSSimulator.xcarchive/Products/Library/Frameworks/MSAL.framework -framework archive/iOS.xcarchive/Products/Library/Frameworks/MSAL.framework -framework archive/macOS.xcarchive/Products/Library/Frameworks/MSAL.framework -output framework/MSAL.xcframework > build.log 2>&1

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

git commit -m "Publish temporary Swift Package $current_date"
git push -f origin "$BRANCH_NAME"

# Download Sample App

echo "Downloading and updating Sample App to use temporary Swift Package"

mkdir -p "$SAMPLE_APP_TEMP_DIR"
cd "$SAMPLE_APP_TEMP_DIR"

git clone https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample.git
cd ms-identity-ciam-native-auth-ios-sample

sed -i '' 's#kind = upToNextMinorVersion;#kind = branch;#' NativeAuthSampleApp.xcodeproj/project.pbxproj
sed -i '' "s#minimumVersion = [0-9.]*;#branch = $BRANCH_NAME;#" NativeAuthSampleApp.xcodeproj/project.pbxproj

rm -f NativeAuthSampleApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

echo "Running the Sample App with the temporary Swift Package"

xcodebuild -resolvePackageDependencies
xcodebuild -scheme NativeAuthSampleApp -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14,OS=latest' clean build