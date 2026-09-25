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

destination="${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

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
  -destination "$destination"
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

