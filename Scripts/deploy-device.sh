#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
PROJECT_PATH="$PROJECT_ROOT/GeminiVoiceKeyboard.xcodeproj"
DEVICE_SELECTOR="${1:-${GEMINI_VOICE_DEVICE_UDID:-${IPHONE_UDID:-}}}"

if [[ -z "$DEVICE_SELECTOR" ]]; then
  DETECTED_DEVICE="$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone" | head -n 1 | awk '{print $3}' || true)"
  if [[ -n "$DETECTED_DEVICE" ]]; then
    DEVICE_SELECTOR="$DETECTED_DEVICE"
    print "📱 Auto-detected connected physical device: $DEVICE_SELECTOR"
  else
    print -u2 "Usage: $0 [CoreDevice identifier or iPhone hardware UDID]"
    print -u2 "Or set GEMINI_VOICE_DEVICE_UDID or IPHONE_UDID in your environment."
    exit 1
  fi
fi

print "🚀 Starting GeminiVoice build & deploy..."
print "📱 Target Device: $DEVICE_SELECTOR"

if command -v xcodegen >/dev/null 2>&1; then
  print "⚙️  Synchronizing project files via xcodegen..."
  (cd "$PROJECT_ROOT" && xcodegen generate --quiet)
fi

print "🔨 Compiling GeminiVoice for iOS device (arm64)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme GeminiVoice \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  -quiet \
  build

# Locate the compiled bundle in DerivedData
APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData/GeminiVoiceKeyboard-*/Build/Products/Debug-iphoneos -name "GeminiVoice.app" -type d 2>/dev/null | head -n 1)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  print -u2 "❌ Build succeeded but GeminiVoice.app could not be found in DerivedData."
  exit 4
fi

APP_BUNDLE_ID="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
    "$APP_PATH/Info.plist" 2>/dev/null || echo "com.example.GeminiVoiceSample"
)"

INSTALL_TARGET="$APP_PATH"
# Prefer Development certificate for get-task-allow / debugging support, fallback to Distribution
if [[ -f "/Users/andrew/Documents/GitHub/Certificates 17/development/MoeDevelopment.pem" && -f "/Users/andrew/Documents/GitHub/Certificates 17/development/MoeDevelopment.mobileprovision" ]]; then
  MOE_PEM="/Users/andrew/Documents/GitHub/Certificates 17/development/MoeDevelopment.pem"
  MOE_PROVISION="/Users/andrew/Documents/GitHub/Certificates 17/development/MoeDevelopment.mobileprovision"
else
  MOE_PEM="/Users/andrew/Documents/GitHub/Certificates 17/distribution/MoeDistribution.pem"
  MOE_PROVISION="/Users/andrew/Documents/GitHub/Certificates 17/distribution/MoeDistribution.mobileprovision"
fi

if command -v plumesign >/dev/null 2>&1 && [[ -f "$MOE_PEM" && -f "$MOE_PROVISION" ]]; then
  print "🔏 Signing with Moe Developer Certificate via plumesign..."
  TMP_STAGE="/tmp/gemini_stage_$$"
  mkdir -p "$TMP_STAGE/Payload"
  cp -R "$APP_PATH" "$TMP_STAGE/Payload/"
  UNSIGNED_IPA="$TMP_STAGE/GeminiVoice_unsigned.ipa"
  SIGNED_IPA="$TMP_STAGE/GeminiVoice_signed.ipa"
  (cd "$TMP_STAGE" && zip -rq "$UNSIGNED_IPA" Payload)

  if plumesign sign \
    --pem "$MOE_PEM" \
    --provision "$MOE_PROVISION" \
    --package "$UNSIGNED_IPA" \
    -o "$SIGNED_IPA" >/dev/null 2>&1; then
    INSTALL_TARGET="$SIGNED_IPA"
    print "✅ Successfully signed with Moe Developer Profile (no 3-app limit)!"
  else
    print "⚠️ plumesign signing failed, falling back to direct install..."
  fi
fi

print "📲 Installing $APP_BUNDLE_ID onto iPhone (updating in-place)..."
xcrun devicectl device install app --device "$DEVICE_SELECTOR" "$INSTALL_TARGET" --timeout 120

[[ -n "${TMP_STAGE:-}" && -d "${TMP_STAGE:-}" ]] && rm -rf "$TMP_STAGE"

print "✨ Installation successful!"
print "🚀 Launching application on iPhone..."

if xcrun devicectl device process launch \
  --device "$DEVICE_SELECTOR" \
  --terminate-existing \
  "$APP_BUNDLE_ID" 2>&1; then
  print "✅ GeminiVoice is running on your iPhone!"
else
  print ""
  print "ℹ️  First-time developer certificate trust required:"
  print "   1. Unlock your iPhone"
  print "   2. Go to Settings ➔ General ➔ VPN & Device Management"
  print "   3. Tap your developer profile and select 'Trust'"
  print "   4. Tap the GeminiVoice icon on your Home Screen"
fi
