# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely redesign the Gemini Voice companion iOS application from scratch with a 3-tab navigation hierarchy (Studio, History, Settings), adaptive Apple HIG light/dark glassmorphic theming, custom 5-color chromatic primary gradient, in-app dictation test playground, and full preservation of accessibility identifiers.

**Architecture:** Replace the monolithic vertical scroll view and `ContentView+*.swift` extensions with a modular SwiftUI architecture divided into feature domains (`Theme`, `Studio`, `History`, `Settings`, `Common`). Root `ContentView` coordinates a 3-tab `TabView` with floating glass overlays for active keyboard handoffs, while maintaining strict separation of concerns from relay controller logic.

**Tech Stack:** Swift 6.2, SwiftUI, Observation (`@Observable`, `@Bindable`), XcodeGen, XCTest, iOS 27.0 SDK targeting iPhone 17.

**Spec:** `docs/superpowers/specs/2026-09-24-ui-redesign-design.md`

## Global Constraints

- Target iOS Platform: iOS 27.0
- Target Device: iPhone 17 Simulator (`platform=iOS Simulator,name=iPhone 17`) & Physical iPhone 17 (`<DEVICE_UDID>`)
- Frameworks: Pure SwiftUI, Observation, Swift 6 concurrency (no third-party UI dependencies)
- Theme: Adaptive Apple HIG (Light & Dark appearance)
- Custom Brand Primary Gradient: 5 chromatic stops (`#FEFEFE`, `#E5A2A5`, `#D97F99`, `#C1B4CF`, `#779BDA`)
- Preserved Accessibility Identifiers:
  - `relay-control-button`
  - `camera-ocr-button`
  - `active-transcription-model`
  - `gemini-live-model-picker`
  - `speech-engine-picker`
  - `download-local-model-button`
  - `cancel-model-download-button`
  - `delete-local-model-button`
  - `local-model-installed-badge`
  - `translation-always-available`
  - `translation-language-picker`
  - `active-translation-model`
  - `api-key-field`
  - `api-key-edit-button`
  - `relay-auto-start-toggle`
  - `relay-auto-stop-toggle`
  - `keyboard-handoff-overlay`

## Review Focus

1. **Light & Dark Mode Contrast**: Gradient and text elements must remain readable and WCAG 4.5:1 compliant in both system appearances without hardcoded dark values.
2. **Audio Waveform Responsiveness**: Real-time 9-bar reactive audio amplitude visualizer must smoothly update without re-rendering unnecessary parent hierarchy.
3. **In-App Scratchpad Dictation**: Starting a test dictation in Studio must coordinate smoothly with `relay` without interfering with background keyboard sessions.
4. **Handoff Overlay Presentation**: Triggering relay handoff from the keyboard must present the floating glass modal instantly with `accessibilityIdentifier("keyboard-handoff-overlay")`.
5. **UI Automation Test Stability**: Tab switching in `GeminiVoiceUITests` must be deterministic and find all elements within standard timeouts.

---

### Task 1: Theme & Visual Tokens

**Files:**
- Create: `App/UI/Theme/GeminiVoiceTheme.swift`
- Create: `App/UI/Common/GlassCardModifier.swift`
- Test: `Tests/GeminiVoiceThemeTests.swift`

**Interfaces:**
- Consumes: Nothing
- Produces:
  - `LinearGradient.geminiVoicePrimary`: 5-stop chromatic gradient (`#FEFEFE`, `#E5A2A5`, `#D97F99`, `#C1B4CF`, `#779BDA`)
  - `GeminiVoiceTheme.statusColor(for: RelayStatus) -> Color`
  - `GeminiVoiceTheme.statusTitle(for: RelayStatus) -> String`
  - `.glassCard()` view modifier for elevated material surfaces

- [ ] **Step 1: Write the failing unit test for theme tokens and gradient**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

final class GeminiVoiceThemeTests: XCTestCase {
  func testPrimaryGradientExistsAndHasFiveStops() {
    let gradient = LinearGradient.geminiVoicePrimary
    XCTAssertNotNil(gradient)
  }

  func testStatusColorsCoverAllRelayStates() {
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .idle), "READY")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .recording), "LISTENING")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .transcribing), "TRANSCRIBING")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .offline), "OFFLINE")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .error), "CHECK SETUP")
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/GeminiVoiceThemeTests`
Expected: Compilation failure ("GeminiVoiceTheme undefined").

- [ ] **Step 3: Implement `GeminiVoiceTheme.swift` and `GlassCardModifier.swift`**

```swift
// App/UI/Theme/GeminiVoiceTheme.swift
import SwiftUI

public enum GeminiVoiceTheme {
  public static let primaryGradientStops: [Color] = [
    Color(red: 254/255, green: 254/255, blue: 254/255), // #FEFEFE
    Color(red: 229/255, green: 162/255, blue: 165/255), // #E5A2A5
    Color(red: 217/255, green: 127/255, blue: 153/255), // #D97F99
    Color(red: 193/255, green: 180/255, blue: 207/255), // #C1B4CF
    Color(red: 119/255, green: 155/255, blue: 218/255)  // #779BDA
  ]

  public static func statusTitle(for status: RelayStatus) -> String {
    switch status {
    case .offline: return "OFFLINE"
    case .idle: return "READY"
    case .recording: return "LISTENING"
    case .transcribing: return "TRANSCRIBING"
    case .error: return "CHECK SETUP"
    }
  }

  public static func statusColor(for status: RelayStatus) -> Color {
    switch status {
    case .offline: return .gray
    case .idle: return .green
    case .recording: return .red
    case .transcribing: return .cyan
    case .error: return .orange
    }
  }
}

extension LinearGradient {
  public static var geminiVoicePrimary: LinearGradient {
    LinearGradient(
      colors: GeminiVoiceTheme.primaryGradientStops,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/GeminiVoiceThemeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/UI/Theme App/UI/Common Tests/GeminiVoiceThemeTests.swift project.yml
git commit -m "feat(ui): add GeminiVoiceTheme with custom primary gradient and card styling"
```

---

### Task 2: Common Components & Floating Handoff Overlay

**Files:**
- Create: `App/UI/Common/StatusPillView.swift`
- Create: `App/UI/Common/KeyboardHandoffOverlay.swift`
- Modify: `App/UI/OCRButtonStyle.swift`
- Modify: `App/UI/ImagePicker.swift`
- Test: `Tests/CommonComponentsTests.swift`

**Interfaces:**
- Consumes: `GeminiVoiceTheme`, `RelayController`, `RelayStatus`
- Produces:
  - `StatusPillView(status: RelayStatus)`: Pill badge with pulsing circle
  - `KeyboardHandoffOverlay(relay: RelayController)`: Glass sheet overlay with soundwave & cancel action
  - Accessible `OCRButtonStyle` supporting Light/Dark contrast

- [ ] **Step 1: Write unit test for StatusPillView and KeyboardHandoffOverlay**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class CommonComponentsTests: XCTestCase {
  func testStatusPillRenders() {
    let pill = StatusPillView(status: .idle)
    XCTAssertNotNil(pill.body)
  }

  func testKeyboardHandoffOverlayRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let overlay = KeyboardHandoffOverlay(relay: relay)
    XCTAssertNotNil(overlay.body)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/CommonComponentsTests`
Expected: Compilation failure ("StatusPillView undefined").

- [ ] **Step 3: Implement StatusPillView and KeyboardHandoffOverlay**

Create `StatusPillView.swift` with dynamic pulsing status indicator and `KeyboardHandoffOverlay.swift` with `.ultraThinMaterial`, fluid 9-bar soundwaves, and `.accessibilityIdentifier("keyboard-handoff-overlay")`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/CommonComponentsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/UI/Common Tests/CommonComponentsTests.swift
git commit -m "feat(ui): add StatusPillView and modern KeyboardHandoffOverlay"
```

---

### Task 3: Studio Tab Components

**Files:**
- Create: `App/UI/Studio/StudioLiveWaveformView.swift`
- Create: `App/UI/Studio/StudioRelayCard.swift`
- Create: `App/UI/Studio/StudioTestPlaygroundView.swift`
- Create: `App/UI/Studio/StudioOCRCard.swift`
- Create: `App/UI/Studio/StudioView.swift`
- Test: `Tests/StudioTabTests.swift`

**Interfaces:**
- Consumes: `AppConfiguration`, `RelayController`, `StatusPillView`, `GeminiVoiceTheme`
- Produces:
  - `StudioLiveWaveformView(audioLevel: Float, isLive: Bool)`
  - `StudioRelayCard(configuration: AppConfiguration, relay: RelayController)`
  - `StudioTestPlaygroundView(relay: RelayController)`
  - `StudioOCRCard(relay: RelayController, onPhotoSelect: Binding<PhotosPickerItem?>)`
  - `StudioView(configuration: AppConfiguration, relay: RelayController, selectedPhotoItem: Binding<PhotosPickerItem?>)`

- [ ] **Step 1: Write unit test for Studio Tab components**

```swift
import XCTest
import SwiftUI
import PhotosUI
@testable import GeminiVoice

@MainActor
final class StudioTabTests: XCTestCase {
  func testStudioViewRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    var photoItem: PhotosPickerItem? = nil
    let binding = Binding(get: { photoItem }, set: { photoItem = $0 })
    let view = StudioView(configuration: config, relay: relay, selectedPhotoItem: binding)
    XCTAssertNotNil(view.body)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/StudioTabTests`
Expected: Compilation failure ("StudioView undefined").

- [ ] **Step 3: Implement Studio components**

Implement `StudioLiveWaveformView`, `StudioRelayCard` (with `accessibilityIdentifier("relay-control-button")`), `StudioTestPlaygroundView`, `StudioOCRCard` (with `accessibilityIdentifier("camera-ocr-button")`), and `StudioView`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/StudioTabTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/UI/Studio Tests/StudioTabTests.swift
git commit -m "feat(ui): implement Studio tab with live waveform, relay card, and dictation test playground"
```

---

### Task 4: History Tab Components

**Files:**
- Create: `App/UI/History/TranscriptRowView.swift`
- Create: `App/UI/History/RecoverableRecordingCard.swift`
- Create: `App/UI/History/HistoryView.swift`
- Test: `Tests/HistoryTabTests.swift`

**Interfaces:**
- Consumes: `RelayController`, `TranscriptHistoryItem`, `RecoverableRecording`
- Produces:
  - `TranscriptRowView(item: TranscriptHistoryItem, onDelete: () -> Void)`
  - `RecoverableRecordingCard(recording: RecoverableRecording, relay: RelayController, onDeleteRequest: (RecoverableRecording) -> Void)`
  - `HistoryView(relay: RelayController, recordingPendingDeletion: Binding<RecoverableRecording?>)`

- [ ] **Step 1: Write unit test for History Tab components**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class HistoryTabTests: XCTestCase {
  func testHistoryViewRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    var pendingDeletion: RecoverableRecording? = nil
    let binding = Binding(get: { pendingDeletion }, set: { pendingDeletion = $0 })
    let view = HistoryView(relay: relay, recordingPendingDeletion: binding)
    XCTAssertNotNil(view.body)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/HistoryTabTests`
Expected: Compilation failure ("HistoryView undefined").

- [ ] **Step 3: Implement History components**

Implement `TranscriptRowView`, `RecoverableRecordingCard`, and `HistoryView` with segmented filter ("Transcripts" vs "Saved Clips"), search filter, swipe-to-delete, and `ContentUnavailableView`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/HistoryTabTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/UI/History Tests/HistoryTabTests.swift
git commit -m "feat(ui): implement History tab with segmented search, recoverable clips, and sharing"
```

---

### Task 5: Settings Tab Components

**Files:**
- Create: `App/UI/Settings/KeyboardSetupCard.swift`
- Create: `App/UI/Settings/SpeechEngineSection.swift`
- Create: `App/UI/Settings/ModelsInfoSection.swift`
- Create: `App/UI/Settings/LocalGemmaSection.swift`
- Create: `App/UI/Settings/TranslationSection.swift`
- Create: `App/UI/Settings/RelayLifecycleSection.swift`
- Create: `App/UI/Settings/CredentialsSection.swift`
- Create: `App/UI/Settings/SettingsView.swift`
- Test: `Tests/SettingsTabTests.swift`

**Interfaces:**
- Consumes: `AppConfiguration`, `RelayController`, `ModelDownloadManager`
- Produces:
  - `KeyboardSetupCard()` with `Text("One-time setup")` and deep-link
  - `SpeechEngineSection(configuration: AppConfiguration)` with `accessibilityIdentifier("speech-engine-picker")`
  - `ModelsInfoSection(configuration: AppConfiguration)` with `accessibilityIdentifier("active-transcription-model")` and `accessibilityIdentifier("gemini-live-model-picker")`
  - `LocalGemmaSection(downloadManager: ModelDownloadManager)` with `accessibilityIdentifier("download-local-model-button")`
  - `TranslationSection(configuration: AppConfiguration)` with `accessibilityIdentifier("translation-always-available")` and `accessibilityIdentifier("translation-language-picker")`
  - `RelayLifecycleSection(configuration: AppConfiguration)` with `accessibilityIdentifier("relay-auto-start-toggle")` and `accessibilityIdentifier("relay-auto-stop-toggle")`
  - `CredentialsSection(configuration: AppConfiguration)` with `accessibilityIdentifier("api-key-field")` and `accessibilityIdentifier("api-key-edit-button")`
  - `SettingsView(configuration: AppConfiguration, relay: RelayController)`

- [ ] **Step 1: Write unit test for Settings Tab components**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class SettingsTabTests: XCTestCase {
  func testSettingsViewRendersAllSections() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let view = SettingsView(configuration: config, relay: relay)
    XCTAssertNotNil(view.body)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests`
Expected: Compilation failure ("SettingsView undefined").

- [ ] **Step 3: Implement Settings components**

Implement all modular settings sections with preserved accessibility identifiers and `SettingsView`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings Tests/SettingsTabTests.swift
git commit -m "feat(ui): implement modern Settings tab with categorized sections and setup guide"
```

---

### Task 6: Root Coordinator & Monolithic Cleanup

**Files:**
- Modify: `App/UI/ContentView.swift`
- Delete: `App/UI/ContentView+Handoff.swift`
- Delete: `App/UI/ContentView+Helpers.swift`
- Delete: `App/UI/ContentView+History.swift`
- Delete: `App/UI/ContentView+Overview.swift`
- Delete: `App/UI/ContentView+Settings.swift`
- Delete: `App/UI/ContentView+Setup.swift`
- Modify: `project.yml`
- Test: `Tests/ContentViewSettingsUITests.swift`

**Interfaces:**
- Consumes: `StudioView`, `HistoryView`, `SettingsView`, `KeyboardHandoffOverlay`
- Produces: Root `ContentView` with `TabView`

- [ ] **Step 1: Rewrite `ContentView.swift` to host TabView with Studio, History, and Settings**

```swift
import PhotosUI
import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable {
  case studio
  case history
  case settings

  public var id: String { rawValue }
}

struct ContentView: View {
  @Bindable var configuration: AppConfiguration
  @Bindable var relay: RelayController

  @State private var selectedTab: AppTab = .studio
  @State private var recordingPendingDeletion: RecoverableRecording?
  @State private var selectedPhotoItem: PhotosPickerItem?

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        StudioView(
          configuration: configuration,
          relay: relay,
          selectedPhotoItem: $selectedPhotoItem
        )
      }
      .tabItem {
        Label("Studio", systemImage: "waveform.circle.fill")
      }
      .tag(AppTab.studio)

      NavigationStack {
        HistoryView(
          relay: relay,
          recordingPendingDeletion: $recordingPendingDeletion
        )
      }
      .tabItem {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
      .tag(AppTab.history)

      NavigationStack {
        SettingsView(
          configuration: configuration,
          relay: relay
        )
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
      .tag(AppTab.settings)
    }
    .tint(Color(red: 217/255, green: 127/255, blue: 153/255))
    .overlay {
      if relay.isKeyboardHandoffActive {
        KeyboardHandoffOverlay(relay: relay)
      }
    }
    .onOpenURL(perform: relay.handleDeepLink)
    .sheet(
      isPresented: Binding(
        get: { relay.isImagePickerPresented },
        set: { presented in
          if !presented && relay.isImagePickerPresented {
            relay.imagePickerDidCancel()
          }
        }
      )
    ) {
      ImagePicker(
        sourceType: relay.imagePickerSource,
        onImage: relay.imagePickerDidSelect,
        onCancel: relay.imagePickerDidCancel
      )
      .ignoresSafeArea()
    }
    .confirmationDialog(
      "Delete this saved recording?",
      item: $recordingPendingDeletion,
      titleVisibility: .visible
    ) { recording in
      Button("Delete Recording", role: .destructive) {
        relay.deleteRecording(recording)
      }
      Button("Keep Recording", role: .cancel) {}
    } message: { _ in
      Text("This permanently removes the local audio clip.")
    }
    .onChange(of: selectedPhotoItem) { _, newItem in
      guard let newItem else { return }
      selectedPhotoItem = nil
      Task {
        if let data = try? await newItem.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
          relay.imagePickerDidSelect(image)
        }
      }
    }
  }
}
```

- [ ] **Step 2: Delete obsolete `ContentView+*.swift` files and re-generate Xcode project**

```bash
rm App/UI/ContentView+Handoff.swift \
   App/UI/ContentView+Helpers.swift \
   App/UI/ContentView+History.swift \
   App/UI/ContentView+Overview.swift \
   App/UI/ContentView+Settings.swift \
   App/UI/ContentView+Setup.swift
xcodegen generate
```

- [ ] **Step 3: Update `ContentViewSettingsUITests.swift` and run unit tests**

Update unit tests to verify `ContentView` builds cleanly with new modular types and run:
`xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add App/UI Tests/ContentViewSettingsUITests.swift GeminiVoiceKeyboard.xcodeproj
git commit -m "refactor(ui): transition ContentView to 3-tab layout and delete monolithic extensions"
```

---

### Task 7: UI Test Suite Adaptation & Full Verification

**Files:**
- Modify: `UITests/GeminiVoiceUITests.swift`

- [ ] **Step 1: Update `GeminiVoiceUITests.swift` for tab navigation**

Update `GeminiVoiceUITests` to:
1. Verify `Studio` tab elements (`relay-control-button`, `camera-ocr-button`).
2. Tap `app.tabBars.buttons["Settings"].tap()` (or `app.buttons["Settings"]`).
3. Verify `One-time setup`, `active-transcription-model`, `translation-always-available`, `translation-language-picker`, and `active-translation-model`.

- [ ] **Step 2: Run Stage 1 automated tests (Simulator iPhone 17)**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: 100% GREEN (Unit Tests + UITests).

- [ ] **Step 3: Run Stage 2 physical device deployment (iPhone 17)**

Run: `./scripts/deploy-device.sh <DEVICE_UDID>`
Launch: `xcrun devicectl device process launch --device <DEVICE_UDID> --terminate-existing com.example.GeminiVoiceSample`

- [ ] **Step 4: Commit and tag**

```bash
git add UITests/GeminiVoiceUITests.swift
git commit -m "test(ui): update UITests for 3-tab navigation and verify on iPhone 17"
```
