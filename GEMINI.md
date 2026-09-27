# Gemini Voice Keyboard — Agent Guidelines & Testing Protocol

This file defines the project-specific operational rules, environment targets, and testing standards for all AI agents working on this codebase.

---

## 1. Strict Target Device Policy: Physical iPhone Only (No Simulator)

All automated testing, test suite execution, UI verification, and physical deployments **must strictly target the physical iPhone**. Do not test on iOS simulators (including iPhone 17 simulator or generic iPad simulators) unless explicitly instructed otherwise.

- **Target Device**: Connected physical iOS device (via `GEMINI_VOICE_DEVICE_UDID`, `IPHONE_UDID`, or auto-detected by `devicectl`, default hardware UDID: `00008150-001943D63E13401C`)
- **iOS Simulator**: Prohibited / Disabled for testing. All test runs and validation must execute on real hardware.
- **Base SDK & Target OS**: iOS 27.0 (Apple Silicon `arm64`)

---

## 2. Physical Device Testing & Deployment Workflow

All builds, test executions, and verifications must run directly on the connected **physical iPhone**.

### 1. Automated Tests (Physical Device)
Execute tests directly on the connected physical iPhone using `Scripts/test.sh` or `xcodebuild`:

```bash
./Scripts/test.sh
```

Or via direct `xcodebuild` invocation targeting the device:

```bash
xcodebuild test \
  -project GeminiVoiceKeyboard.xcodeproj \
  -scheme GeminiVoice \
  -destination "platform=iOS,id=${GEMINI_VOICE_DEVICE_UDID:-00008150-001943D63E13401C}"
```

*All unit tests in `GeminiVoiceTests` and `GeminiKeyboardPortTests` must be 100% green on device before proceeding.*

### 2. Physical Device Deployment & Launch
Deploy the build directly to the connected **physical iPhone**:

```bash
./Scripts/deploy-device.sh [DEVICE_UDID]
```

If the device is locked, prompt the user to unlock the iPhone and launch via `devicectl`:

```bash
xcrun devicectl device process launch --device <DEVICE_UDID> --terminate-existing com.example.GeminiVoiceSample
```

---

## 3. Tooling & Architecture Standards

1. **Hardware Verification Priority**:
   - Run tests and launch apps on the physical iPhone only. Do not invoke simulator test runners (`test_sim`, `build_run_sim`) for verification.
   - Clean Builds: Use `clean` or `xcodebuild clean`.
2. **Separation of Concerns (SoC)**: Keep presentation (`App/UI`), relay coordination (`App/Relay`), audio capture (`App/Audio`), local models (`App/LocalAI`), and configuration (`App/Application`) cleanly decoupled.
3. **Apple Framework Documentation**: Before modifying or introducing Apple APIs or SwiftUI modifiers, always query `apple-doc-plugin` via `semantic_search`.
4. **Preserve Accessibility Identifiers**: Maintain existing UI identifiers (`relay-control-button`, `speech-engine-picker`, `relay-auto-start-toggle`, etc.) to prevent test regressions.
