# Keyboard Recording Panel Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Keyboard Extension's recording panel into a modern Frosted Glass Card featuring the active model tag at the top, a chromatic twilight audio waveform in the middle, and bold status typography at the bottom.

**Architecture:** Move `SpeechEngineMode` into `Shared/` so both host app and keyboard extension share engine metadata and preferences. Replace the legacy UIKit subviews in the keyboard's recording panel with a modern SwiftUI component (`KeyboardRecordingCardView`) hosted in a `UIHostingController`. The card reactively displays the active speech engine model badge, live gradient audio waveform, and dynamic title ("Listening" / "Listening to translate").

**Tech Stack:** Swift 6.2, SwiftUI, UIKit, Observation, MobileBuildMCP, XCTest.

**Spec:** Derived through collaborative `/grill-me` session documented in conversation history.

---

## Global Constraints

- **Strict Target Device: iPhone 17 Only**: Simulator (`platform=iOS Simulator,name=iPhone 17`) and physical device (`<DEVICE_UDID>`).
- **Preserve Accessibility Identifiers**: Maintain `keyboard-recording-panel` and child labels.
- **Visual Design Rules**: Frosted glass (`.ultraThinMaterial`), continuous corners (`cornerRadius: 22, style: .continuous`), chromatic twilight gradient (`#FEFEFE, #E5A2A5, #D97F99, #C1B4CF, #779BDA`), high-contrast accessible typography.
- **Passivity**: Recording card does not intercept tap gestures; action controls remain in the top toolbar (`↑` finish, `×` cancel).

---

## Review Focus

1. **Active Engine Reflection**: Verify changing speech engine mode in Settings persists to App Group shared defaults and immediately updates the model badge on the keyboard's recording card.
2. **Translation Mode Title**: Verify initiating translation dictation sets the card title to "Listening to translate" while normal dictation shows "Listening".
3. **Audio Waveform Responsiveness**: Verify the 9-bar chromatic waveform smoothly scales with live audio levels without causing layout invalidation or memory leaks.
4. **Dark & Light Mode Adaptation**: Verify hairline borders and frosted materials adapt correctly across dark and light color schemes.
5. **No Layout Overflow on iPhone 17**: Verify card height stays within keyboard bounds (~210pt) without clipping the bottom globe/mic accessories.

---

## Task Decomposition

### Task 1: Share `SpeechEngineMode` Across App & Keyboard Targets

**Files:**
- Move: `App/Application/SpeechEngineMode.swift` -> `Shared/SpeechEngine/SpeechEngineMode.swift`
- Modify: `App/Application/AppConfiguration.swift:81-86`
- Modify: `project.yml:55-58`
- Test: `Tests/SpeechEngineModeTests.swift`

**Interfaces:**
- Produces: `SpeechEngineMode` accessible in `KeyboardExtension` and `GeminiVoice`.
- Produces: `AppConfiguration.Key.speechEngineMode` synced to `sharedDefaults`.

- [ ] **Step 1: Write failing test verifying shared preferences persistence**

```swift
func testSpeechEngineModeSynchronizesToSharedDefaults() {
  let suite = "group.test.gemini.speech.mode.\(UUID().uuidString)"
  let sharedDefaults = UserDefaults(suiteName: suite)!
  defer { sharedDefaults.removePersistentDomain(forName: suite) }
  
  let config = AppConfiguration(defaults: sharedDefaults)
  config.speechEngineMode = .localOnDevice
  
  XCTAssertEqual(sharedDefaults.string(forKey: "gemini.speech-engine-mode"), SpeechEngineMode.localOnDevice.rawValue)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mobilebuildmcp.test_sim`
Expected: FAIL with missing assertion or compile failure.

- [ ] **Step 3: Move file and update AppConfiguration to mirror to sharedDefaults**

Move `SpeechEngineMode.swift` to `Shared/SpeechEngine/SpeechEngineMode.swift`.
In `AppConfiguration.swift`:
```swift
var speechEngineMode: SpeechEngineMode {
  didSet {
    defaults.set(speechEngineMode.rawValue, forKey: Key.speechEngineMode)
    sharedDefaults.set(speechEngineMode.rawValue, forKey: Key.speechEngineMode)
    sharedDefaults.synchronize()
  }
}
```
Regenerate project with `xcodegen generate`.

- [ ] **Step 4: Run test to verify it passes**

Run: `mobilebuildmcp.test_sim`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add Shared/SpeechEngine/SpeechEngineMode.swift App/Application/AppConfiguration.swift Tests/SpeechEngineModeTests.swift project.yml GeminiVoiceKeyboard.xcodeproj
git commit -m "refactor: move SpeechEngineMode to Shared and mirror to App Group defaults"
```

---

### Task 2: Build `KeyboardRecordingCardView` in SwiftUI

**Files:**
- Create: `KeyboardExtension/UI/KeyboardRecordingCardView.swift`
- Test: `Tests/KeyboardRecordingCardTests.swift`

**Interfaces:**
- Consumes: `GeminiVoiceTheme`, `SpeechEngineMode`, `KeyboardAudioVisualizerState`.
- Produces: `KeyboardRecordingCardView(modeName: String, modeIcon: String, title: String, visualizer: KeyboardAudioVisualizerState)`

- [ ] **Step 1: Write unit tests for KeyboardRecordingCardView**

Create `Tests/KeyboardRecordingCardTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class KeyboardRecordingCardTests: XCTestCase {
  func testRecordingCardRendersWithListeningTitle() {
    let visualizer = KeyboardAudioVisualizerState()
    let card = KeyboardRecordingCardView(
      modeName: "Gemini 3.5 Live",
      modeIcon: "bolt.badge.automatic.fill",
      title: "Listening",
      visualizer: visualizer
    )
    XCTAssertNotNil(card.body)
  }

  func testRecordingCardRendersTranslationTitle() {
    let visualizer = KeyboardAudioVisualizerState()
    let card = KeyboardRecordingCardView(
      modeName: "Local Gemma 2B",
      modeIcon: "lock.shield.fill",
      title: "Listening to translate",
      visualizer: visualizer
    )
    XCTAssertNotNil(card.body)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mobilebuildmcp.test_sim`
Expected: FAIL with "cannot find 'KeyboardRecordingCardView' in scope".

- [ ] **Step 3: Implement KeyboardRecordingCardView**

Create `KeyboardExtension/UI/KeyboardRecordingCardView.swift`:
- Top: Model badge pill (`Image(systemName: modeIcon)` + `Text(modeName)` in frosted capsule).
- Middle: 9-bar chromatic waveform (`[GeminiVoiceTheme.accentColor, Color(red: 119/255, green: 155/255, blue: 218/255)]`).
- Bottom: `Text(title).font(.system(size: 18, weight: .bold, design: .rounded))`.
- Background: `.ultraThinMaterial` with continuous corner curve 22, hairline white stroke, and soft shadow.

- [ ] **Step 4: Run test to verify it passes**

Run: `mobilebuildmcp.test_sim`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add KeyboardExtension/UI/KeyboardRecordingCardView.swift Tests/KeyboardRecordingCardTests.swift project.yml GeminiVoiceKeyboard.xcodeproj
git commit -m "feat: implement KeyboardRecordingCardView with chromatic waveform and model badge"
```

---

### Task 3: Integrate `KeyboardRecordingCardView` into `KeyboardViewController`

**Files:**
- Modify: `KeyboardExtension/Controller/KeyboardViewController+Layout.swift:120-163`
- Modify: `KeyboardExtension/Controller/KeyboardViewController+Presentation.swift:115-138`
- Modify: `KeyboardExtension/UI/KeyboardToolbarState.swift`

**Interfaces:**
- Consumes: `KeyboardRecordingCardView`, `sharedPreferences`.
- Produces: Seamlessly hosts SwiftUI recording card replacing legacy UIKit subviews.

- [ ] **Step 1: Write integration assertions**

Add assertions in `Tests/KeyboardRecordingCardTests.swift` verifying layout and accessibility hierarchy.

- [ ] **Step 2: Run test to verify it fails**

Run: `mobilebuildmcp.test_sim`
Expected: FAIL on new assertions.

- [ ] **Step 3: Host KeyboardRecordingCardView in recordingPanel**

In `KeyboardViewController+Layout.swift`:
Embed `UIHostingController(rootView: ...)` into `recordingPanel`.
In `KeyboardViewController+Presentation.swift`:
Update `updateRecordingPresentation(with:)` to dynamically update audio levels and speech engine title/icon.

- [ ] **Step 4: Run test to verify it passes**

Run: `mobilebuildmcp.test_sim`
Expected: PASS (100% green test suite).

- [ ] **Step 5: Commit**

```bash
git add KeyboardExtension/Controller/KeyboardViewController+Layout.swift KeyboardExtension/Controller/KeyboardViewController+Presentation.swift Tests/KeyboardRecordingCardTests.swift
git commit -m "feat: host KeyboardRecordingCardView in keyboard recordingPanel"
```

---

### Task 4: Full Verification & Physical iPhone 17 Deployment

- [ ] **Step 1: Execute full test suite on iPhone 17 simulator**
```bash
mobilebuildmcp.test_sim
```
Expected: 100% green (165+ passing tests).

- [ ] **Step 2: Deploy directly to physical iPhone 17**
```bash
./scripts/deploy-device.sh <DEVICE_UDID>
```
Expected: Build succeeds, app installs, and process launches.
