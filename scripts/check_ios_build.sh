#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

PROJECT="jianshengjily.xcodeproj"
TARGET="jianshengjily"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Please install Xcode."
  exit 1
fi

DEVELOPER_DIR_PATH="$(xcode-select -p 2>/dev/null || true)"
case "$DEVELOPER_DIR_PATH" in
  */CommandLineTools)
    echo "Current developer directory is Command Line Tools:"
    echo "$DEVELOPER_DIR_PATH"
    echo
    echo "Install full Xcode, then run:"
    echo "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
    ;;
esac

if ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
  if xcrun --sdk iphonesimulator --show-sdk-path 2>&1 | grep -qi "license"; then
    echo "Xcode license has not been accepted. Run:"
    echo "sudo xcodebuild -license accept"
    exit 1
  fi

  echo "iOS Simulator SDK not found. Open Xcode once and install iOS platform support."
  exit 1
fi

xcodebuild \
  -project "$PROJECT" \
  -target "$TARGET" \
  -sdk iphonesimulator \
  -configuration Debug \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
