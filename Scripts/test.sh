#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"

cd "$project_root"
xcodegen_bin="${XCODEGEN_BIN:-$(command -v xcodegen || true)}"
if [[ -n "$xcodegen_bin" ]]; then
  "$xcodegen_bin" generate
else
  echo "XcodeGen not found; using the committed Xcode project."
fi

device_id="$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]*iPhone[^\(]*\(([A-F0-9-]+)\) \((Booted|Shutdown)\).*$/\1/p' | head -n 1)"
if [[ -z "$device_id" ]]; then
  echo "No available iPhone simulator was found."
  exit 1
fi

scheme="GeminiVoice"
raw_output=0
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--unit-only)
      scheme="GeminiVoiceUnitTests"
      shift
      ;;
    --raw)
      raw_output=1
      shift
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

cmd=(
  xcodebuild
  -project GeminiVoiceKeyboard.xcodeproj
  -scheme "$scheme"
  -destination "platform=iOS Simulator,id=$device_id"
  -derivedDataPath DerivedData
  -collect-test-diagnostics never
)

if [[ ${#extra_args[@]} -gt 0 ]]; then
  cmd+=("${extra_args[@]}")
fi

cmd+=(test)

if [[ "$raw_output" -eq 0 ]] && command -v xcbeautify >/dev/null 2>&1; then
  "${cmd[@]}" | xcbeautify
else
  "${cmd[@]}"
fi

