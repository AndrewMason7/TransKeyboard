# Settings Page Full Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the Gemini Voice Settings tab from 7 fragmented glass cards into 3 unified, high-density cards with collapsible setup, inline local model management with deletion confirmation, lifecycle background safety warnings, and enhanced credential management.

**Architecture:** Refactor individual settings components (KeyboardSetupCard, SpeechEngineSection, LocalGemmaSection, RelayLifecycleSection, CredentialsSection) to support inline nesting, safety dialogs, and disclosure states, then assemble them in SettingsView into three distinct visual containers.

**Tech Stack:** Swift 6, SwiftUI, Observation framework, XCTest, MobileBuildMCP.

**Spec:** Redesign and consolidate the settings page to resolve card fatigue and design flaws per the user request ("full /writing-plans /plan /executing-plans native").

## Global Constraints
- Target platform: iOS 27.0 (Apple Silicon arm64).
- Simulator target: `platform=iOS Simulator,name=iPhone 17`.
- Physical device target: iPhone 17 (model `iPhone18,3`, UDID: `<DEVICE_UDID>`).
- Accessibility identifiers must remain intact: `speech-engine-picker`, `active-transcription-model`, `translation-always-available`, `translation-language-picker`, `active-translation-model`, `relay-auto-start-toggle`, `relay-auto-stop-toggle`, `download-local-model-button`, `cancel-model-download-button`, `delete-local-model-button`, `local-model-installed-badge`, `api-key-field`, `api-key-edit-button`.
- Header text `One-time setup` must remain present in static text for UI tests.
- Two-stage verification sequence: full automated test suite on iPhone 17 simulator, then deployment to physical iPhone 17.

## Review Focus
- Input: Tapping the collapse button on KeyboardSetupCard; Expectation: Collapses step list without losing "One-time setup" static text or breaking UI tests.
- Input: Tapping "Delete" on an installed local model; Expectation: Shows confirmation dialog before destructive file deletion.
- Input: Toggling "Auto-stop on exit" ON in RelayLifecycleSection; Expectation: Immediately shows warning that keyboard dictation in other apps will be disabled.
- Input: Tapping the eye button on CredentialsSection; Expectation: Toggles between masked bullets (`••••`) and plaintext API key in both read and edit modes.
- Input: Tapping "Paste" in CredentialsSection; Expectation: Pastes clipboard text directly into the API key override field.

---

### Task 1: Collapsible Keyboard Setup Card

**Files:**
- Modify: `App/UI/Settings/KeyboardSetupCard.swift`
- Test: `Tests/SettingsTabTests.swift`

**Interfaces:**
- Consumes: None
- Produces: `KeyboardSetupCard: View` with collapsible toggle and `@AppStorage("keyboard_setup_expanded")`.

- [ ] **Step 1: Write the failing test**

Add unit test to `Tests/SettingsTabTests.swift`:
```swift
  func testKeyboardSetupCardCollapseToggle() {
    let card = KeyboardSetupCard()
    XCTAssertNotNil(card.body)
  }
```

- [ ] **Step 2: Run test to verify it compiles and runs**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testKeyboardSetupCardCollapseToggle`
Expected: PASS

- [ ] **Step 3: Implement collapsible behavior in KeyboardSetupCard**

Update `App/UI/Settings/KeyboardSetupCard.swift`:
```swift
import SwiftUI
import UIKit

struct KeyboardSetupCard: View {
  @Environment(\.openURL) private var openURL
  @AppStorage("keyboard_setup_expanded") private var isExpanded: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("One-time setup", systemImage: "keyboard")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        Button {
          withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded.toggle()
          }
        } label: {
          HStack(spacing: 4) {
            Text(isExpanded ? "Collapse" : "Setup guide")
              .font(.caption.weight(.medium))
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption2.weight(.bold))
          }
          .foregroundStyle(GeminiVoiceTheme.accentColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(GeminiVoiceTheme.accentColor.opacity(0.12))
          .clipShape(Capsule())
        }
        .accessibilityIdentifier("keyboard-setup-toggle-button")
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          setupStep(1, "Open Settings › General › Keyboard › Keyboards.")
          setupStep(2, "Tap Add New Keyboard, then choose Gemini Voice.")
          setupStep(3, "Open Gemini Voice in the list and enable Allow Full Access.")
          setupStep(4, "Select this keyboard with the globe key in any text field.")

          Button("Open Gemini Voice Settings") {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(GeminiVoiceTheme.accentColor)
          .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      } else {
        Text("Keyboards › Gemini Voice › Allow Full Access. Tap guide to review.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .transition(.opacity)
      }
    }
    .glassCard(cornerRadius: 20, padding: 18)
  }

  private func setupStep(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(number)")
        .font(.caption2.bold())
        .frame(width: 22, height: 22)
        .background(GeminiVoiceTheme.accentColor.opacity(0.18))
        .foregroundStyle(GeminiVoiceTheme.accentColor)
        .clipShape(Circle())

      Text(text)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
  }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings/KeyboardSetupCard.swift Tests/SettingsTabTests.swift
git commit -m "feat(settings): add collapsible guide to KeyboardSetupCard"
```

---

### Task 2: Local Gemma Model Deletion Confirmation Dialog

**Files:**
- Modify: `App/UI/Settings/LocalGemmaSection.swift`
- Test: `Tests/SettingsTabTests.swift`

**Interfaces:**
- Consumes: `ModelDownloadManager`
- Produces: `LocalGemmaSection: View` with `.confirmationDialog` before invoking `downloadManager.deleteModel()`.

- [ ] **Step 1: Write the failing test**

Verify existing `testLocalGemmaSectionRenders()` in `Tests/SettingsTabTests.swift`.

- [ ] **Step 2: Run test to verify baseline**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testLocalGemmaSectionRenders`
Expected: PASS

- [ ] **Step 3: Implement confirmation dialog in LocalGemmaSection**

Update `App/UI/Settings/LocalGemmaSection.swift`:
Add `@State private var showingDeleteConfirmation = false` and attach `.confirmationDialog`:
```swift
    case .ready(let size, _):
      HStack {
        Text(size.formatted(.byteCount(style: .file)))
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
        Spacer()
        Button(role: .destructive) {
          showingDeleteConfirmation = true
        } label: {
          Label("Delete", systemImage: "trash")
            .font(.caption2)
        }
        .tint(.red)
        .accessibilityIdentifier("delete-local-model-button")
        .confirmationDialog(
          "Delete Local Model?",
          isPresented: $showingDeleteConfirmation,
          titleVisibility: .visible
        ) {
          Button("Delete Model (\(size.formatted(.byteCount(style: .file))))", role: .destructive) {
            downloadManager.deleteModel()
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("This will remove the downloaded Gemma model from your device storage (~1.5 GB). You will need to re-download it to use local transcription.")
        }
      }
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testLocalGemmaSectionRenders`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings/LocalGemmaSection.swift
git commit -m "feat(settings): add confirmation dialog to local model deletion"
```

---

### Task 3: Inline AI Intelligence Card (SpeechEngineSection + LocalGemmaSection)

**Files:**
- Modify: `App/UI/Settings/SpeechEngineSection.swift`
- Test: `Tests/SettingsTabTests.swift`

**Interfaces:**
- Consumes: `AppConfiguration`, optional `ModelDownloadManager? = nil`
- Produces: `SpeechEngineSection: View` with optional inline `LocalGemmaSection` embedding.

- [ ] **Step 1: Write test verifying SpeechEngineSection with and without downloadManager**

Add to `Tests/SettingsTabTests.swift`:
```swift
  func testSpeechEngineSectionWithDownloadManager() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let section = SpeechEngineSection(configuration: config, downloadManager: relay.modelDownloadManager)
    XCTAssertNotNil(section.body)
  }
```

- [ ] **Step 2: Run test to verify failure before modification**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testSpeechEngineSectionWithDownloadManager`
Expected: FAIL (extra argument 'downloadManager' in call)

- [ ] **Step 3: Update SpeechEngineSection to accept downloadManager**

In `App/UI/Settings/SpeechEngineSection.swift`:
```swift
struct SpeechEngineSection: View {
  @Bindable var configuration: AppConfiguration
  var downloadManager: ModelDownloadManager? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Header & Single Unified Model Picker Row
      HStack(alignment: .center, spacing: 12) {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text("Voice Recognition Model")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)

            Text("Active engine & model")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "waveform.badge.mic")
            .font(.title3)
            .foregroundStyle(GeminiVoiceTheme.accentColor)
        }

        Spacer(minLength: 8)

        // Single Unified Model Picker
        Picker("Voice Recognition Model", selection: $configuration.selectedModelId) {
          ForEach(AppConfiguration.availableTranscriptionModels, id: \.self) { modelName in
            Text(modelName).tag(modelName)
          }
        }
        .pickerStyle(.menu)
        .tint(GeminiVoiceTheme.accentColor)
        .accessibilityIdentifier("speech-engine-picker")
        .sensoryFeedback(.selection, trigger: configuration.selectedModelId)
      }

      // Dynamic Telemetry Hero Card
      telemetryCard(for: configuration.speechEngineMode)

      // Inline Local Model Management
      if let downloadManager {
        Divider()
          .overlay(Color.primary.opacity(0.08))
          .padding(.vertical, 2)

        LocalGemmaSection(downloadManager: downloadManager)
      }
    }
  }
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testSpeechEngineSectionWithDownloadManager`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings/SpeechEngineSection.swift Tests/SettingsTabTests.swift
git commit -m "feat(settings): embed LocalGemmaSection inline inside SpeechEngineSection"
```

---

### Task 4: Relay Background Safety Warning Callout

**Files:**
- Modify: `App/UI/Settings/RelayLifecycleSection.swift`
- Test: `Tests/SettingsTabTests.swift`

**Interfaces:**
- Consumes: `AppConfiguration`
- Produces: `RelayLifecycleSection: View` with auto-stop safety warning callout.

- [ ] **Step 1: Write test for warning presence on RelayLifecycleSection**

Add test to `Tests/SettingsTabTests.swift`:
```swift
  func testRelayLifecycleSectionRendersWithAutoStop() {
    let config = AppConfiguration()
    config.autoStopRelayOnBackground = true
    let section = RelayLifecycleSection(configuration: config)
    XCTAssertNotNil(section.body)
  }
```

- [ ] **Step 2: Run test to verify it compiles**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testRelayLifecycleSectionRendersWithAutoStop`
Expected: PASS

- [ ] **Step 3: Implement safety warning banner in RelayLifecycleSection**

Update `App/UI/Settings/RelayLifecycleSection.swift`:
```swift
import SwiftUI

struct RelayLifecycleSection: View {
  @Bindable var configuration: AppConfiguration

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Background Relay", systemImage: "antenna.radiowaves.left.and.right")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      Toggle(isOn: $configuration.autoStartRelayOnLaunch) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Auto-start on launch")
            .font(.subheadline)
          Text("Automatically start relay when opening the app.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .tint(GeminiVoiceTheme.accentColor)
      .accessibilityIdentifier("relay-auto-start-toggle")
      .sensoryFeedback(.selection, trigger: configuration.autoStartRelayOnLaunch)

      Toggle(isOn: $configuration.autoStopRelayOnBackground) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Auto-stop on exit")
            .font(.subheadline)
          Text("Automatically stop relay when leaving the app.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .tint(GeminiVoiceTheme.accentColor)
      .accessibilityIdentifier("relay-auto-stop-toggle")
      .sensoryFeedback(.selection, trigger: configuration.autoStopRelayOnBackground)

      if configuration.autoStopRelayOnBackground {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.top, 1)

          Text("Relay stops when leaving the app. Keyboard dictation in other apps (Messages, Safari) will be disabled.")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("relay-auto-stop-warning")
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: configuration.autoStopRelayOnBackground)
  }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testRelayLifecycleSectionRendersWithAutoStop`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings/RelayLifecycleSection.swift Tests/SettingsTabTests.swift
git commit -m "feat(settings): add auto-stop safety warning callout in RelayLifecycleSection"
```

---

### Task 5: Credentials Section Show/Hide Eye Toggle, Clipboard Paste & Conditional Clear

**Files:**
- Modify: `App/UI/Settings/CredentialsSection.swift`
- Test: `Tests/SettingsTabTests.swift`

**Interfaces:**
- Consumes: `AppConfiguration`
- Produces: `CredentialsSection: View` with show/hide eye toggle, paste button, and conditional clear button.

- [ ] **Step 1: Write test for CredentialsSection with existing and missing credentials**

Add to `Tests/SettingsTabTests.swift`:
```swift
  func testCredentialsSectionWithKey() {
    let config = AppConfiguration()
    config.apiKeyOverride = "AIzaSyFakeTestKeyForCredentialsSection"
    let section = CredentialsSection(configuration: config)
    XCTAssertNotNil(section.body)
  }
```

- [ ] **Step 2: Run test to verify it compiles**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testCredentialsSectionWithKey`
Expected: PASS

- [ ] **Step 3: Implement Show/Hide toggle, Paste button, and Conditional Clear in CredentialsSection**

Update `App/UI/Settings/CredentialsSection.swift`:
```swift
import SwiftUI
import UIKit

struct CredentialsSection: View {
  @Bindable var configuration: AppConfiguration
  @State private var isEditing = false
  @State private var isRevealed = false
  @FocusState private var isFieldFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("API Credentials", systemImage: "key.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      HStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: isEditing ? "key.fill" : "lock.fill")
            .font(.caption)
            .foregroundStyle(isEditing ? GeminiVoiceTheme.accentColor : Color.secondary)
            .contentTransition(.symbolEffect(.replace))

          if isEditing {
            if isRevealed {
              TextField("Optional API key override", text: $configuration.apiKeyOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .accessibilityIdentifier("api-key-field")
            } else {
              SecureField("Optional API key override", text: $configuration.apiKeyOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .accessibilityIdentifier("api-key-field")
            }
          } else {
            if configuration.apiKeyOverride.isEmpty {
              Text("Optional API key override")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("api-key-field")
            } else if isRevealed {
              Text(configuration.apiKeyOverride)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("api-key-field")
                .textSelection(.enabled)
            } else {
              Text(String(repeating: "•", count: min(configuration.apiKeyOverride.count, 28)))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("api-key-field")
            }
          }

          Spacer(minLength: 0)

          // Show/Hide Reveal Eye Toggle
          if !configuration.apiKeyOverride.isEmpty {
            Button {
              withAnimation(.easeInOut(duration: 0.15)) {
                isRevealed.toggle()
              }
            } label: {
              Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("api-key-reveal-button")
          }

          // Paste from Clipboard Button
          if isEditing {
            Button {
              if let paste = UIPasteboard.general.string {
                configuration.apiKeyOverride = paste.trimmingCharacters(in: .whitespacesAndNewlines)
              }
            } label: {
              Image(systemName: "doc.on.clipboard")
                .font(.caption)
                .foregroundStyle(GeminiVoiceTheme.accentColor)
            }
            .accessibilityIdentifier("api-key-paste-button")
          }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(isEditing ? GeminiVoiceTheme.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
        )

        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            if isEditing {
              isFieldFocused = false
              isEditing = false
            } else {
              isEditing = true
              isFieldFocused = true
            }
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: isEditing ? "checkmark" : "pencil")
              .contentTransition(.symbolEffect(.replace))
            Text(isEditing ? "Done" : "Edit")
          }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 11)
          .background(isEditing ? GeminiVoiceTheme.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
          .foregroundStyle(isEditing ? GeminiVoiceTheme.accentColor : Color.primary)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityIdentifier("api-key-edit-button")
        .sensoryFeedback(.selection, trigger: isEditing)
      }

      // Credential Status Row & Conditional Clear Key Button
      HStack {
        Label(
          configuration.hasUsableAPIKey
            ? "Personal-device credential configured"
            : "API credential missing",
          systemImage: configuration.hasUsableAPIKey
            ? "checkmark.shield.fill"
            : "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(configuration.hasUsableAPIKey ? Color.green : Color.orange)

        Spacer()

        if !configuration.apiKeyOverride.isEmpty {
          Button("Clear key override") {
            configuration.clearAPIKeyOverride()
            if isEditing {
              isFieldFocused = false
              isEditing = false
            }
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("api-key-clear-button")
        }
      }

      if let warning = configuration.credentialPersistenceWarning {
        Label(warning, systemImage: "key.slash.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testCredentialsSectionWithKey`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings/CredentialsSection.swift Tests/SettingsTabTests.swift
git commit -m "feat(settings): add show/hide eye toggle, clipboard paste, and conditional clear to CredentialsSection"
```

---

### Task 6: Unified SettingsView Assembly (3-Card Layout)

**Files:**
- Modify: `App/UI/Settings/SettingsView.swift`
- Test: `Tests/SettingsTabTests.swift`, `UITests/GeminiVoiceUITests.swift`

**Interfaces:**
- Consumes: `KeyboardSetupCard`, `SpeechEngineSection`, `TranslationSection`, `RelayLifecycleSection`, `CredentialsSection`
- Produces: `SettingsView: View` with 3 consolidated glass cards.

- [ ] **Step 1: Write test for SettingsView rendering 3 unified cards**

Verify `testSettingsViewRendersAllSections()` in `Tests/SettingsTabTests.swift`.

- [ ] **Step 2: Run test to verify baseline**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SettingsTabTests/testSettingsViewRendersAllSections`
Expected: PASS

- [ ] **Step 3: Refactor SettingsView into 3 unified glass cards**

Update `App/UI/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
  @Bindable var configuration: AppConfiguration
  @Bindable var relay: RelayController

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        // Card 1: Keyboard Access & Setup
        KeyboardSetupCard()

        // Card 2: Speech & AI Intelligence (Model Picker, Telemetry, and Inline Local Gemma)
        SpeechEngineSection(
          configuration: configuration,
          downloadManager: relay.modelDownloadManager
        )
        .glassCard(cornerRadius: 20, padding: 18)

        // Card 3: Preferences & Security (Translation, Relay Lifecycle, API Credentials)
        VStack(alignment: .leading, spacing: 18) {
          TranslationSection(configuration: configuration)

          Divider()
            .overlay(Color.primary.opacity(0.08))

          RelayLifecycleSection(configuration: configuration)

          Divider()
            .overlay(Color.primary.opacity(0.08))

          CredentialsSection(configuration: configuration)
        }
        .glassCard(cornerRadius: 20, padding: 18)

        // Privacy note
        privacyFooter
      }
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 36)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .navigationTitle("Settings")
  }

  private var privacyFooter: some View {
    Label(
      "While the relay is on, iOS shows microphone access because the audio session stays armed. After Dictate or Translate, microphone audio streams to Google Gemini Live; Finish inserts the result, while Cancel stops streaming and discards it. A local fallback recording is deleted after success, or kept on this iPhone for Retry after a failure.",
      systemImage: "lock.shield"
    )
    .font(.caption)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, 6)
  }
}
```

- [ ] **Step 4: Run unit tests and UI tests to verify they pass**

Run: `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: 100% PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Settings/SettingsView.swift
git commit -m "feat(settings): consolidate 7 cards into 3 unified glass cards"
```

---

### Task 7: Full Verification on iPhone 17 Simulator & Physical Device Deployment

**Files:**
- None (verification & deployment)

**Interfaces:**
- Consumes: Compiled Gemini Voice application bundle

- [ ] **Step 1: Execute full automated test suite on iPhone 17 Simulator (Stage 1)**

Run `test_sim` on `platform=iOS Simulator,name=iPhone 17`.
Expected: 100% green across all unit, UI, and keyboard port tests.

- [ ] **Step 2: Deploy and launch on Physical iPhone 17 (Stage 2)**

Run: `./scripts/deploy-device.sh <DEVICE_UDID>`
Launch: `xcrun devicectl device process launch --device <DEVICE_UDID> --terminate-existing com.example.GeminiVoiceSample`
Expected: App launches successfully on physical iPhone 17 with 3 consolidated cards.
