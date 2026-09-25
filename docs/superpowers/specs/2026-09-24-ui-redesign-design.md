# UI Redesign Specification — Gemini Voice Companion App

**Date:** 2026-09-24  
**Status:** Approved  
**Author:** Pair Programming Agent & User  

---

## 1. Executive Summary & Goals

The Gemini Voice iOS companion application currently presents all relay controls, setup instructions, settings, recoverable audio recordings, and recent transcripts in a single vertical scroll view with an expandable accordion. While functional, this monolithic layout clutters the interface, requires excessive vertical scrolling, and does not leverage modern iOS navigation paradigms.

This specification outlines a complete architectural redesign of the user interface from scratch:
- **Navigation Architecture**: Transition from a single-screen feed to a focused 3-tab layout: **Studio**, **History**, and **Settings**.
- **Aesthetic & Theme**: Modern Adaptive Apple Human Interface Guidelines (HIG) with full Light and Dark mode support, dynamic system materials (`.ultraThinMaterial`), and a custom chromatic twilight gradient palette.
- **Brand Palette**: Custom user-defined Primary Gradient using 5 chromatic stops: `#FEFEFE` (Pearly White), `#E5A2A5` (Blossom Rose), `#D97F99` (Soft Magenta), `#C1B4CF` (Soft Lavender), and `#779BDA` (Periwinkle Blue).
- **Interactive Studio Playground**: Add an in-app speech-to-text test input playground so users can immediately test dictation, audio capture, and translation without leaving the app.
- **Searchable History Hub**: Provide a dedicated hub for viewing, searching, sharing, and copying past dictations, alongside managing and retrying failed/saved audio recordings.
- **Modern Settings & Setup**: Deliver an inset grouped settings surface with an interactive keyboard setup card with direct deep-links to iOS Settings.
- **Strict Accessibility & Test Compatibility**: Preserve all existing accessibility identifiers (`relay-control-button`, `camera-ocr-button`, `active-transcription-model`, `speech-engine-picker`, etc.) and update `GeminiVoiceUITests` to validate tab transitions on iPhone 17.

---

## 2. Visual System & Theming

### 2.1 Primary Brand Gradient
The primary brand aesthetic utilizes a five-stop chromatic aura gradient:
- Stop 1: `#FEFEFE` (Pearlescent White)
- Stop 2: `#E5A2A5` (Muted Blossom Rose)
- Stop 3: `#D97F99` (Soft Magenta)
- Stop 4: `#C1B4CF` (Muted Lavender)
- Stop 5: `#779BDA` (Periwinkle Sky Blue)

In SwiftUI:
```swift
extension LinearGradient {
  public static var geminiVoicePrimary: LinearGradient {
    LinearGradient(
      colors: [
        Color(red: 254/255, green: 254/255, blue: 254/255),
        Color(red: 229/255, green: 162/255, blue: 165/255),
        Color(red: 217/255, green: 127/255, blue: 153/255),
        Color(red: 193/255, green: 180/255, blue: 207/255),
        Color(red: 119/255, green: 155/255, blue: 218/255)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
```

### 2.2 Adaptive Materials & Surfaces
- **Background**:
  - Light Appearance: `Color(UIColor.systemGroupedBackground)` with subtle pearlescent accent tints.
  - Dark Appearance: `Color(UIColor.systemBackground)` with dark glass backing.
- **Card Containers**:
  - Elevated surfaces with `.ultraThinMaterial` / `.regularMaterial`.
  - Corner radius: `20pt` with subtle continuous borders (`Color.primary.opacity(0.06)`).
- **Haptics & Motion**:
  - Haptics: `.sensoryFeedback(.impact(weight: .medium), trigger: ...)` and `.sensoryFeedback(.selection, trigger: ...)`.
  - Motion: Spring animations (`.spring(response: 0.35, dampingFraction: 0.8)`) with full support for `@Environment(\.accessibilityReduceMotion)`.

---

## 3. Information Architecture & Navigation

The root view (`ContentView`) hosts a `TabView` with three primary tabs, coordinated via `@State private var selectedTab: AppTab = .studio`:

```
┌────────────────────────────────────────────────────────────────┐
│  ContentView (Root)                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ TabView                                                  │  │
│  │                                                          │  │
│  │  [Tab 1: Studio]     [Tab 2: History]   [Tab 3: Settings]│  │
│  │   • Relay Status      • Transcripts      • Setup Card    │  │
│  │   • Live Waveform     • Search Bar       • Speech Engine │  │
│  │   • Test Scratchpad   • Failed Clips     • Gemini Live   │  │
│  │   • Camera OCR        • Retry / Clear    • Local Gemma   │  │
│  │                                          • API Key       │  │
│  └──────────────────────────────────────────────────────────┘  │
│  Overlays & Sheets:                                            │
│   • KeyboardHandoffOverlay (Floating Glass Sheet)              │
│   • ImagePicker Sheet (Camera & Photos)                        │
└────────────────────────────────────────────────────────────────┘
```

### 3.1 Tab 1: Studio (`StudioView`)
- **Header**: Gemini Voice brand title with interactive status indicator and active model tag.
- **Relay Status Card (`StudioRelayCard`)**:
  - Current relay state pill (`statusPill`: Offline, Ready, Listening, Transcribing, Check Setup).
  - Descriptive status message from `relay.statusMessage`.
  - 2-minute idle shutdown informative callout when armed.
  - Tactile action button (`accessibilityIdentifier("relay-control-button")`) to toggle the background relay on/off.
- **Live Waveform Visualizer (`StudioLiveWaveformView`)**:
  - Real-time 9-bar reactive audio amplitude visualizer responding to `relay.audioLevel` with spring physics.
- **In-App Test Playground (`StudioTestPlaygroundView`)**:
  - An interactive scratchpad card where users can tap "Test Dictation", speak into the microphone, view real-time transcribed text, and verify audio capture without switching apps.
- **Camera & Image OCR Card (`StudioOCRCard`)**:
  - Take Photo action button (`accessibilityIdentifier("camera-ocr-button")`) using `UIImagePickerController`.
  - Choose Image button using `PhotosPicker`.
  - Real-time OCR processing spinner and status messages.

### 3.2 Tab 2: History (`HistoryView`)
- **Segmented Control**:
  - Segment 1: "Transcripts" (all completed dictations).
  - Segment 2: "Saved Clips" (recoverable recordings that failed or were interrupted, with a count badge).
- **Transcripts Feed**:
  - Searchable bar (`.searchable(text: $searchText)`).
  - Transcript cards showing timestamp, text content, copy-to-clipboard button, and `ShareLink`.
  - Swipe-to-delete or individual remove action.
  - "Clear All" button with sensory feedback.
  - Modern empty state using `ContentUnavailableView("No Transcripts Yet", systemImage: "text.quote", ...)`.
- **Saved / Failed Clips List**:
  - Shows failed audio recording filename/title, timestamp, and error reason (`recording.lastError`).
  - Inline "Retry" button (with spinner during retry) that re-submits the audio clip to Gemini.
  - Trash button with deletion confirmation dialog to discard the audio clip.
  - Modern empty state using `ContentUnavailableView("No Saved Recordings", systemImage: "waveform.badge.checkmark", ...)`.

### 3.3 Tab 3: Settings (`SettingsView`)
- **Interactive Keyboard Setup Card (`KeyboardSetupCard`)**:
  - Visual 4-step guide:
    1. Open Settings › General › Keyboard › Keyboards
    2. Tap Add New Keyboard › Gemini Voice
    3. Open Gemini Voice and enable Allow Full Access
    4. Select keyboard with globe key
  - Deep-link button: "Open Gemini Voice Settings" opening `UIApplication.openSettingsURLString`.
  - Retains header `Text("One-time setup")` for automated UI test validation.
- **Speech Engine Section (`SpeechEngineSection`)**:
  - Segmented picker (`accessibilityIdentifier("speech-engine-picker")`): Gemini Live vs Apple On-Device Speech.
- **Gemini Models Section (`ModelsInfoSection`)**:
  - Active transcription model label (`accessibilityIdentifier("active-transcription-model")`).
  - Gemini Live model picker (`accessibilityIdentifier("gemini-live-model-picker")`).
  - Fallback model label.
- **Local Gemma Model Section (`LocalGemmaSection`)**:
  - Storage badge, download button (`accessibilityIdentifier("download-local-model-button")`), progress bar, cancel (`accessibilityIdentifier("cancel-model-download-button")`), and delete (`accessibilityIdentifier("delete-local-model-button")`).
  - Installed badge (`accessibilityIdentifier("local-model-installed-badge")`).
- **Translation Section (`TranslationSection`)**:
  - "Translate is always available" label (`accessibilityIdentifier("translation-always-available")`).
  - Target language picker (`accessibilityIdentifier("translation-language-picker")`).
  - Active translation model (`accessibilityIdentifier("active-translation-model")`).
- **Relay Lifecycle Section (`RelayLifecycleSection`)**:
  - Auto-start on launch toggle (`accessibilityIdentifier("relay-auto-start-toggle")`).
  - Auto-stop on exit toggle (`accessibilityIdentifier("relay-auto-stop-toggle")`).
- **Credentials Section (`CredentialsSection`)**:
  - Secure API key override field (`accessibilityIdentifier("api-key-field")`) with edit/done toggle (`accessibilityIdentifier("api-key-edit-button")`).
  - Keychain diagnostic warning callouts.

---

## 4. Floating Overlays & Sheets

### 4.1 Keyboard Handoff Overlay (`KeyboardHandoffOverlay`)
When dictation is triggered from the keyboard extension and returns to the app (`relay.isKeyboardHandoffActive == true`), a floating glass sheet is presented:
- Container: Floating frosted glass card over blurred ambient background.
- Primary visual: 5-color chromatic primary gradient mark with pulsing mic icon.
- Soundwaves: Fluid 9-bar reactive audio amplitude meter.
- Titles: Dynamic status ("Listening", "Finishing", "Returning to your keyboard").
- Action: "Cancel recording" / "Cancel handoff" button.
- Accessibility: `accessibilityIdentifier("keyboard-handoff-overlay")`.

---

## 5. File Architecture & Decoupling (SoC)

Old monolithic structure (`ContentView+*.swift`) is replaced by modular component files in `App/UI/`:

```
App/UI/
├── ContentView.swift                  # Root coordinator & TabView container
├── Theme/
│   └── GeminiVoiceTheme.swift         # Brand colors, 5-stop chromatic gradient, card styles
├── Studio/
│   ├── StudioView.swift               # Tab 1 root view
│   ├── StudioRelayCard.swift          # Live relay status & tactile control
│   ├── StudioLiveWaveformView.swift   # Audio level visualizer
│   ├── StudioTestPlaygroundView.swift # In-app dictation test scratchpad
│   └── StudioOCRCard.swift            # Camera & photo OCR action card
├── History/
│   ├── HistoryView.swift              # Tab 2 root view with segmented picker & search
│   ├── TranscriptRowView.swift        # Formatted transcript item with copy/share
│   └── RecoverableRecordingCard.swift # Failed clip with retry spinner & delete
├── Settings/
│   ├── SettingsView.swift             # Tab 3 root view
│   ├── KeyboardSetupCard.swift        # Visual setup walkthrough with deep-link
│   ├── SpeechEngineSection.swift      # Engine picker & documentation
│   ├── ModelsInfoSection.swift        # Active/live/fallback model selections
│   ├── LocalGemmaSection.swift        # Download progress, bytes gauge, delete
│   ├── TranslationSection.swift       # Translation target picker & models
│   ├── RelayLifecycleSection.swift    # Auto-start/stop toggles
│   └── CredentialsSection.swift       # API key field & Keychain diagnostics
└── Common/
    ├── KeyboardHandoffOverlay.swift   # Floating glass sheet for active handoff
    ├── StatusPillView.swift           # Status capsule badge (Offline, Ready, Listening)
    ├── GlassCardModifier.swift        # Reusable card styling modifier
    ├── ImagePicker.swift              # UIImagePickerController wrapper
    └── OCRButtonStyle.swift           # Common accessible button styles
```

---

## 6. Verification & Automated Testing Plan

1. **Unit Tests**:
   - `ContentViewSettingsUITests.swift`: Updated to instantiate and test `ContentView`, `ModelsInfoSection`, and `SpeechEngineSection`.
   - Run `xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17'`.
2. **UI Tests**:
   - `UITests/GeminiVoiceUITests.swift`: Updated to test tab transitions:
     - Verify `Studio` tab controls (`relay-control-button`, `camera-ocr-button`).
     - Switch to `Settings` tab (`app.buttons["Settings"].tap()` or tab bar item).
     - Verify `One-time setup`, `active-transcription-model`, `translation-always-available`, `translation-language-picker`, `active-translation-model`.
   - Run `xcodebuild test -scheme GeminiVoice -destination 'platform=iOS Simulator,name=iPhone 17'`.
3. **Physical Device Deployment**:
   - Deploy to iPhone 17 (UDID: `<DEVICE_UDID>`) using `./scripts/deploy-device.sh`.
