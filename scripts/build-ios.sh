#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/packages/ios/YappatronIOS/YappatronIOS.xcodeproj"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required. Install Xcode, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme YappatronIOS \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
