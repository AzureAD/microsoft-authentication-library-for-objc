BRANCH_NAME="$1"
# visionOS device + simulator slices are included by default so the published
# xcframework never ships out of sync with Package.swift's .visionOS() platform.
# Use --skip-visionos on fast paths (e.g. regular PR validation) that do not have
# the visionOS SDK installed. --include-visionos is kept as a no-op alias for
# backward compatibility with existing callers.
INCLUDE_VISIONOS=true
SKIP_SAMPLE_APP=false

# Parse optional flags
for arg in "$@"; do
  case $arg in
    --include-visionos)
      INCLUDE_VISIONOS=true
      ;;
    --skip-visionos)
      INCLUDE_VISIONOS=false
      ;;
    --skip-sample-app)
      SKIP_SAMPLE_APP=true
      ;;
  esac
done

SAMPLE_APP_TEMP_DIR="NativeAuthSampleAppTemp"
current_date=$(date +"%Y-%m-%d %H:%M:%S")

set -e

# xcodebuild steps below run with -quiet and redirect output to build.log, so a
# failure would otherwise exit with no actionable context in the CI log. On a
# non-zero exit, dump build.log so the underlying xcodebuild error is visible.
# This script is invoked via `sh`, so use a POSIX-compatible EXIT trap that
# checks the status rather than a bash-only ERR trap.
on_exit()
{
    status=$?
    if [ "$status" -ne 0 ]; then
        echo "** Build step failed (exit $status). Contents of build.log: **"
        cat build.log 2>/dev/null || echo "(build.log not found)"
    fi
}
trap on_exit EXIT

# Build framework

echo "Building framework"

xcodebuild -sdk iphonesimulator -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/iOSSimulator CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
xcodebuild -sdk iphoneos -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/iOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
xcodebuild -sdk macosx -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (Mac Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/macOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1

XCFRAMEWORK_ARGS="-framework archive/iOSSimulator.xcarchive/Products/Library/Frameworks/MSAL.framework -framework archive/iOS.xcarchive/Products/Library/Frameworks/MSAL.framework -framework archive/macOS.xcarchive/Products/Library/Frameworks/MSAL.framework"

if [ "$INCLUDE_VISIONOS" = true ]; then
  echo "Including visionOS in xcframework"
  xcodebuild -sdk xrsimulator -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/visionOSSimulator CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
  xcodebuild -sdk xros -configuration Release -workspace MSAL.xcworkspace -scheme "MSAL (iOS Framework)" archive SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -archivePath archive/visionOS CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1
  XCFRAMEWORK_ARGS="$XCFRAMEWORK_ARGS -framework archive/visionOSSimulator.xcarchive/Products/Library/Frameworks/MSAL.framework -framework archive/visionOS.xcarchive/Products/Library/Frameworks/MSAL.framework"
else
  echo "Skipping visionOS (use default, or pass --include-visionos, to include; --skip-visionos to opt out)"
fi

xcodebuild -create-xcframework $XCFRAMEWORK_ARGS -output framework/MSAL.xcframework > build.log 2>&1

if [ "$INCLUDE_VISIONOS" = true ]; then
  echo "Verifying visionOS slices are present in MSAL.xcframework"
  if [ ! -f framework/MSAL.xcframework/Info.plist ]; then
    echo "** ERROR: framework/MSAL.xcframework/Info.plist not found; xcframework creation likely failed. See build.log above. **"
    exit 1
  fi
  python3 - <<'PY'
import plistlib, sys

plist_path = "framework/MSAL.xcframework/Info.plist"
with open(plist_path, "rb") as f:
    info = plistlib.load(f)

libraries = info.get("AvailableLibraries", [])

def has_slice(platform, simulator):
    for lib in libraries:
        is_sim = lib.get("SupportedPlatformVariant") == "simulator"
        if lib.get("SupportedPlatform") == platform and is_sim == simulator:
            return True
    return False

missing = []
if not has_slice("xros", False):
    missing.append("visionOS device (xros)")
if not has_slice("xros", True):
    missing.append("visionOS simulator (xros-simulator)")

if missing:
    sys.stderr.write("** ERROR: MSAL.xcframework is missing required slices: " + ", ".join(missing) + " **\n")
    sys.exit(1)

print("Verified visionOS device + simulator slices are present in MSAL.xcframework")
PY
fi

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