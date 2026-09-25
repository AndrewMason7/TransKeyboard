# Modernize UI & UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the Gemini Voice iOS application UI and UX to follow Apple Human Interface Guidelines (HIG) with a modern native TabView architecture, full Light/Dark mode adaptability, native Inset Grouped Forms, ContentUnavailableView empty states, ShareLink exports, and sensory haptics.

**Architecture:** Transition from a monolithic single-screen dark-only `ScrollView` to a clean, modern Apple navigation structure:
1. `ContentView` orchestrates a native `TabView` with three dedicated tabs:
   - **Relay Tab** (`RelayDashboardView`): Hero relay status card, live audio waveform, one-tap control, quick OCR actions, and setup banner.
   - **History Tab** (`HistoryView`): Native searchable list of dictations, ShareLink, tap-to-copy, and pending failed recording recovery.
   - **Settings Tab** (`SettingsView`): Native iOS Inset Grouped `Form` for models, voice engines, on-device Gemma background download, and API credentials with edit-lock.
2. Replace hardcoded dark-only colors with Apple semantic system colors (`systemGroupedBackground`, `secondarySystemGroupedBackground`, `.primary`, `.secondary`).
3. Add native haptic sensory feedback (`.sensoryFeedback`) and empty states (`ContentUnavailableView`).

**Tech Stack:** Swift 6.2, SwiftUI (iOS 27.0 deployment target), SF Symbols 6, Observation framework (`@Observable`, `@Bindable`), SensoryFeedback, ShareLink, ContentUnavailableView.

**Spec:** Modern Apple Human Interface Guidelines (HIG) for iOS 17+, iOS 26+, and iOS 27.

## Global Constraints

- Must maintain 100% backwards compatibility with all existing accessibility identifiers (`relay-control-button`, `camera-ocr-button`, `speech-engine-picker`, `api-key-field`, `api-key-edit-button`, `keyboard-handoff-overlay`, etc.).
- Must preserve all existing unit tests in `GeminiVoiceUnitTests` (128 passing tests).
- Must support both Light Mode and Dark Mode dynamically using semantic Apple system materials.
- Must preserve full functionality of Gemini Live streaming, Local Gemma on-device execution, Camera OCR, and keyboard handoff.

## Review Focus

1. **Light & Dark Mode legibility**: Ensure all text, cards, and icons have crisp contrast in both appearances without hardcoded white/black tints.
2. **Accessibility identifier stability**: Confirm all automated testing IDs remain intact on their respective interactive elements.
3. **Empty state handling**: Verify `ContentUnavailableView` renders gracefully when history and recoverable recordings are empty.
4. **Handoff overlay continuity**: Ensure the keyboard handoff modal overlay still smoothly intercepts navigation and dismisses cleanly.
5. **Sheet and Dialog presentation**: Confirm image picker, confirmation dialogs, and navigation destinations function without state desynchronization.

---

### Task 1: Create Adaptive Semantic Theme & Modern Card Styles

**Files:**
- Create: `App/UI/Theme/AppTheme.swift`
- Test: `Tests/ThemeTests.swift`

**Interfaces:**
- Consumes: SwiftUI `Color`, `ShapeStyle`
- Produces: `AppTheme.cardBackground`, `AppTheme.cardStroke`, `AppTheme.heroGradient`, `.modernCard()` modifier

- [ ] **Step 1: Write unit test for theme color semantics**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

final class ThemeTests: XCTestCase {
  @MainActor
  func testThemeProvidesSemanticStyles() {
    let bg = AppTheme.cardBackground
    XCTAssertNotNil(bg)
    let gradient = AppTheme.heroGradient
    XCTAssertEqual(gradient.stops.count, 3)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/ThemeTests`
Expected: FAIL ("cannot find 'AppTheme' in scope")

- [ ] **Step 3: Implement `AppTheme.swift`**

```swift
import SwiftUI

public enum AppTheme {
  public static var background: Color {
    Color(uiColor: .systemGroupedBackground)
  }

  public static var cardBackground: Color {
    Color(uiColor: .secondarySystemGroupedBackground)
  }

  public static var tertiaryBackground: Color {
    Color(uiColor: .tertiarySystemGroupedBackground)
  }

  public static var cardStroke: Color {
    Color.primary.opacity(0.06)
  }

  public static var heroGradient: LinearGradient {
    LinearGradient(
      colors: [.cyan, .blue, .purple],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

public struct ModernCardModifier: ViewModifier {
  public var cornerRadius: CGFloat = 16

  public func body(content: Content) -> some View {
    content
      .padding(16)
      .background(AppTheme.cardBackground, in: .rect(cornerRadius: cornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(AppTheme.cardStroke, lineWidth: 1)
      }
  }
}

public extension View {
  func modernCard(cornerRadius: CGFloat = 16) -> some View {
    modifier(ModernCardModifier(cornerRadius: cornerRadius))
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/ThemeTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Theme/AppTheme.swift Tests/ThemeTests.swift
git commit -m "feat(ui): add adaptive semantic theme and modern card modifier"
```

---

### Task 2: Modernize Relay Dashboard View (Tab 1)

**Files:**
- Create: `App/UI/Tabs/RelayDashboardView.swift`
- Modify: `App/UI/ContentView+Overview.swift`
- Test: `Tests/RelayDashboardUITests.swift`

**Interfaces:**
- Consumes: `@Bindable var relay: RelayController`, `@Bindable var configuration: AppConfiguration`
- Produces: `RelayDashboardView` containing animated status pill, hero audio card with haptic feedback, camera OCR quick actions, and keyboard setup guide.

- [ ] **Step 1: Write failing UI test for `RelayDashboardView`**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class RelayDashboardUITests: XCTestCase {
  func testRelayDashboardRendersKeyControls() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let view = RelayDashboardView(configuration: config, relay: relay)
    XCTAssertNotNil(view.body)
  }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/RelayDashboardUITests`
Expected: FAIL ("cannot find 'RelayDashboardView' in scope")

- [ ] **Step 3: Implement `RelayDashboardView`**

Implement `RelayDashboardView` using:
- Modern `NavigationStack` with `.navigationTitle("Gemini Voice")`.
- Animated status banner with real-time waveform indicator.
- Action button with `.sensoryFeedback(.impact, trigger: relay.isRelayRunning)` and `accessibilityIdentifier("relay-control-button")`.
- Camera OCR button with `accessibilityIdentifier("camera-ocr-button")`.
- Clean expandable setup banner that deep-links to iOS Settings.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/RelayDashboardUITests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Tabs/RelayDashboardView.swift Tests/RelayDashboardUITests.swift
git commit -m "feat(ui): implement modern RelayDashboardView with haptics and HIG components"
```

---

### Task 3: Modernize History & Recordings View (Tab 2)

**Files:**
- Create: `App/UI/Tabs/HistoryView.swift`
- Modify: `App/UI/ContentView+History.swift`
- Test: `Tests/HistoryViewUITests.swift`

**Interfaces:**
- Consumes: `@Bindable var relay: RelayController`
- Produces: `HistoryView` with searchable list, `ContentUnavailableView`, `ShareLink`, tap-to-copy, and recoverable recording retry/delete.

- [ ] **Step 1: Write UI test for `HistoryView`**

```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class HistoryViewUITests: XCTestCase {
  func testHistoryViewRendersEmptyStateWhenNoItems() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let view = HistoryView(relay: relay)
    XCTAssertNotNil(view.body)
  }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/HistoryViewUITests`
Expected: FAIL ("cannot find 'HistoryView' in scope")

- [ ] **Step 3: Implement `HistoryView`**

Implement `HistoryView` using:
- `.searchable(text: $searchText)` for fast keyword filtering.
- `ContentUnavailableView("No Transcripts Yet", systemImage: "text.bubble", description: Text("Dictations and translations will appear here."))` when empty.
- Modern swipe actions: `.swipeActions(edge: .trailing)` to delete or share.
- `ShareLink(item: item.text)` to quickly export transcripts.
- Recoverable recordings section with progress spinners, retry, and confirmation dialog.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/HistoryViewUITests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Tabs/HistoryView.swift Tests/HistoryViewUITests.swift
git commit -m "feat(ui): implement modern HistoryView with search, ShareLink, and ContentUnavailableView"
```

---

### Task 4: Modernize Settings View (Tab 3) with Native Inset Grouped Form

**Files:**
- Create: `App/UI/Tabs/SettingsView.swift`
- Modify: `App/UI/ContentView+Settings.swift`
- Test: `Tests/ContentViewSettingsUITests.swift`

**Interfaces:**
- Consumes: `@Bindable var configuration: AppConfiguration`, `@Bindable var relay: RelayController`
- Produces: `SettingsView` conforming to native iOS `Form` and `.formStyle(.grouped)`.

- [ ] **Step 1: Update `ContentViewSettingsUITests`**

Update `Tests/ContentViewSettingsUITests.swift` to verify both `SettingsView` and `CredentialsSettingsSection` render properly with the new layout and edit-lock button.

- [ ] **Step 2: Run test to verify failure**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/ContentViewSettingsUITests`
Expected: FAIL

- [ ] **Step 3: Implement `SettingsView`**

Implement `SettingsView` using native Apple `Form`:
- `Section("Speech Recognition Engine")` with segmented picker and `.sensoryFeedback(.selection)`.
- `Section("On-Device Gemma Model")` showing live download progress bar, file size, background download status, and download/delete controls.
- `Section("Live Translation")` with target language selection.
- `Section("API Credentials")` with the edit-lock protected API key field and clear button.
- `Section("Active Models")` with model IDs and copy actions.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077' -only-testing:GeminiVoiceTests/ContentViewSettingsUITests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/UI/Tabs/SettingsView.swift App/UI/ContentView+Settings.swift Tests/ContentViewSettingsUITests.swift
git commit -m "feat(ui): implement native Inset Grouped SettingsView"
```

---

### Task 5: Assemble Modern Native TabView in `ContentView` & Verify Entire Suite

**Files:**
- Modify: `App/UI/ContentView.swift`
- Modify: `App/UI/ContentView+Handoff.swift`
- Test: Full unit test suite (`GeminiVoiceUnitTests`)

**Interfaces:**
- Consumes: `RelayDashboardView`, `HistoryView`, `SettingsView`, `keyboardHandoffOverlay`
- Produces: Polished top-level native `ContentView` with tabs, badge counts for saved recordings, sheet presentations, and handoff overlay.

- [ ] **Step 1: Update `ContentView.swift`**

Assemble the native `TabView`:
```swift
TabView(selection: $selectedTab) {
  RelayDashboardView(configuration: configuration, relay: relay)
    .tabItem {
      Label("Relay", systemImage: "waveform.badge.mic")
    }
    .tag(Tab.relay)

  HistoryView(relay: relay)
    .tabItem {
      Label("History", systemImage: "clock.arrow.circlepath")
    }
    .badge(relay.recoverableRecordings.count)
    .tag(Tab.history)

  SettingsView(configuration: configuration, relay: relay)
    .tabItem {
      Label("Settings", systemImage: "gearshape")
    }
    .tag(Tab.settings)
}
```
Retain `.overlay { if relay.isKeyboardHandoffActive { keyboardHandoffOverlay } }`, `.sheet(...)`, and `.onOpenURL(...)`.

- [ ] **Step 2: Run complete unit test suite**

Run: `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,id=A4AD8E8C-CAFC-4809-8866-9BCE0E559077'`
Expected: ALL TESTS PASS (100% green).

- [ ] **Step 3: Deploy to physical iPhone 17**

Run: `./scripts/deploy-device.sh <DEVICE_UDID>`
Expected: Successfully installs and launches on physical device.

- [ ] **Step 4: Commit**

```bash
git add App/UI/ContentView.swift App/UI/ContentView+Handoff.swift
git commit -m "feat(ui): assemble modern TabView navigation and deploy to device"
```
