#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
PROJECT_PATH="$PROJECT_ROOT/GeminiVoiceKeyboard.xcodeproj"
DERIVED_DATA="$PROJECT_ROOT/build/DeviceDerivedData"
OUTPUT_DIR="$PROJECT_ROOT/build"
IPA_PATH="$OUTPUT_DIR/GeminiVoice.ipa"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/GeminiVoice.app"

print "==> Building GeminiVoice with automatic code signing..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme GeminiVoice \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build

print "==> Packaging IPA..."
rm -rf "$OUTPUT_DIR/Payload" "$IPA_PATH"
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/"
(cd "$OUTPUT_DIR" && zip -r -y -q "$IPA_PATH" Payload)
rm -rf "$OUTPUT_DIR/Payload"

print "==> Successfully created signed IPA at: $IPA_PATH"
ls -lh "$IPA_PATH"
