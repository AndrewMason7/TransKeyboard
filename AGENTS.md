# Gemini Voice Keyboard — Agent Guidelines & Testing Protocol

This file defines the project-specific operational rules, environment targets, and testing standards for all AI agents working on this codebase.

---

## 1. Strict Target Device Policy: iPhone 17 Only

All automated testing, UI verification, and physical deployments **must strictly target iPhone 17**. Do not target other device generations (e.g. iPhone 15, iPhone 16, or generic iPad simulators) unless explicitly instructed by the user.

- **iOS Simulator Target**: `platform=iOS Simulator,name=iPhone 17`
- **Physical Device Target**: Connected physical iOS device (via `GEMINI_VOICE_DEVICE_UDID` or passed as argument)
- **Base SDK & Target OS**: iOS 27.0 (Apple Silicon `arm64`)

---

## 2. MobileBuildMCP & Two-Stage Verification Workflow

Always prefer **MobileBuildMCP** tools (`ServerName: "mobilebuildmcp_mobilebuildmcp"`) over raw `xcodebuild`, `xcrun`, or `simctl` commands for simulator building, running, testing, and UI verification.

### Session Defaults Context
Call `session_show_defaults` at the beginning of each session. If not populated, set:
- **Project**: `GeminiVoiceKeyboard.xcodeproj`
- **Scheme**: `GeminiVoice`
- **Simulator**: `iPhone 17`

Do NOT run `discover_projs` speculatively if project context is already known.

### Stage 1: Automated Unit & UI Tests (Simulator via MobileBuildMCP)
Execute the full test suite targeting the **iPhone 17** simulator using MobileBuildMCP `test_sim`:

```json
{
  "scheme": "GeminiVoice",
  "simulatorName": "iPhone 17"
}
```

*All unit tests in `GeminiVoiceTests` and `GeminiKeyboardPortTests` must be 100% green before proceeding.*

### Stage 2: Physical Device Deployment & Launch
Deploy the build directly to a connected **physical iPhone**:

```bash
./Scripts/deploy-device.sh [DEVICE_UDID]
```

If the device is locked, prompt the user to unlock the iPhone and launch via `devicectl`:

```bash
xcrun devicectl device process launch --device <DEVICE_UDID> --terminate-existing com.example.GeminiVoiceSample
```

---

## 3. Tooling & Architecture Standards

1. **MobileBuildMCP Tool Priority**:
   - Building and launching on simulator: Use `build_run_sim` (with `scheme: "GeminiVoice"`, `simulatorName: "iPhone 17"`). Do not chain separate boot/install/launch steps.
   - UI Automation & Inspections: Use `snapshot_ui` and `screenshot` on `iPhone 17` to inspect hierarchy and verify layout.
   - Clean Builds: Use `clean`.
2. **Separation of Concerns (SoC)**: Keep presentation (`App/UI`), relay coordination (`App/Relay`), audio capture (`App/Audio`), local models (`App/LocalAI`), and configuration (`App/Application`) cleanly decoupled.
3. **Apple Framework Documentation**: Before modifying or introducing Apple APIs or SwiftUI modifiers, always query `apple-doc-plugin` via `semantic_search`.
4. **Preserve Accessibility Identifiers**: Maintain existing UI identifiers (`relay-control-button`, `speech-engine-picker`, `relay-auto-start-toggle`, etc.) to prevent test regressions.
