# TransKeyboard — Gemini Voice Keyboard for iOS

An end-to-end iOS application and custom keyboard featuring cloud-powered streaming speech transcription & translation via **Google Gemini 3.5 Live**, 100% offline on-device speech-to-text via Apple's neural **`SFSpeechRecognizer`**, and optional local on-device intelligence powered by **Gemma 4 LiteRT-LM**.

Tap **Dictate** or **Translate** directly on the custom keyboard, speak, tap again, and the polished text is inserted directly into the active text field.

---

## Key Highlights & Capabilities

### 🎙️ Multi-Engine Speech Architecture
Choose your speech transcription and translation pipeline in **Settings**:

| Engine Mode | Primary Transcriber | Post-Processing & Translation | Network Requirement |
| :--- | :--- | :--- | :--- |
| **Gemini Live (Cloud)** | `gemini-3.5-transcribe-live` | `gemini-3.5-live-translate-preview` | Internet Required |
| **Local On-Device** | Apple Neural Speech (`SFSpeechRecognizer`) | On-device Gemma 4 or smart heuristic punctuation | **100% Offline (Zero Data Sent)** |
| **Gemini Live with Fallback** | `gemini-3.5-transcribe-live` | Auto-falls back to On-Device Speech when offline | Resilient to Network Dropouts |

- **Zero-Download Offline Transcription**: Works out of the box with 0 MB downloaded using Apple's on-device speech model.
- **Optional Local Gemma 4 Model**: Download [Gemma 4 E2B LiteRT-LM](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm) (`gemma-4-E2B-it.litert-lm`, ~2.5 GB) directly on-device from Settings for offline punctuation, formatting, and translation. Can be deleted at any time to reclaim storage.

---

### 📱 Modern 3-Tab App Architecture

The containing application is built with a glassmorphic SwiftUI design system:

* **Studio**:
  - Live microphone audio visualizer with reactive decibel waveform.
  - Interactive Relay Controller card for toggling recording and testing microphone handoff.
  - OCR Text Extraction card (via camera capture or photo library selection).
  - Dictation Test Playground with rich typography and instant clear actions.
* **History**:
  - Searchable transcript archive with session timestamps and word counts.
  - Inline audio playback for recorded sessions.
  - Recovery cards for safely restoring interrupted or orphaned recordings.
  - Native iOS Share Sheet export for transcripts.
* **Settings**:
  - Secure iOS Keychain storage for Gemini API keys (enter directly in-app, no config files required).
  - Speech engine picker (Gemini Live vs. Local On-Device vs. Hybrid Fallback).
  - Gemma 4 Model Manager: one-tap download with live progress, byte counters, and storage cleanup.
  - Interactive Keyboard Setup Guide for enabling Full Access.

---

### ⌨️ Native Apple-Matching Keyboard Surface

The custom keyboard typing surface adapts layout principles from KeyboardKit 9.9.1 with zero runtime binary dependencies:

- **Apple Native Geometry**: Calibrated keycap height and bottom margin alignment right above the system home indicator and globe area.
- **Dark Theme Aesthetics**: System `#424242` background, 8.5 pt rounded keycaps, crisp high-contrast glyphs, and zero borderlines.
- **Zero-Latency Typing**: Instantaneous case transitions without crossfade delay, multi-touch rollover, and touch-slop gesture handling to eliminate dropped keystrokes.
- **Floating Voice Toolbar**: Dedicated voice control bar featuring a reactive status pill, live audio metering, tactile haptic feedback, and accessible touch targets.

---

## How It Works

iOS keyboard extensions cannot directly record audio due to sandbox security restrictions. TransKeyboard bridges this with an App Group relay coordinator:

```text
Custom Keyboard Process
  │  start / finish / cancel + UUID request ID
  ▼
Locked App Group Store (file-locked, monotonic sequence)
  │
  ▼
Containing App Relay Process
  ├─ SFSpeechRecognizer (Offline) ──┐
  ├─ PCM Stream → Gemini Live (WS) ─┼─► Formatted Result
  └─ Gemma 4 / Local Text Processor ┘
  │
  ▼
Locked App Group Result (matching request + document anchor guard)
  │
  ▼
UITextDocumentProxy.insertText (Active Text Field)
```

---

## Source Layout

| Area | Location | Description |
| :--- | :--- | :--- |
| **Studio Tab** | [`App/UI/Studio`](App/UI/Studio) | Waveform visualizer, relay card, OCR tool, and sandbox |
| **History Tab** | [`App/UI/History`](App/UI/History) | Searchable transcript store, playback, and session recovery |
| **Settings Tab** | [`App/UI/Settings`](App/UI/Settings) | Credentials, speech engine selection, and Gemma download manager |
| **Local AI & Models** | [`App/LocalAI`](App/LocalAI) | On-device speech recognizer, text processor, and model manager |
| **Gemini Live & Batch** | [`App/Gemini`](App/Gemini) | WebSocket transport, Live protocol, and batch fallbacks |
| **Audio Capture** | [`App/Audio`](App/Audio) | `AVAudioEngine` capture, PCM conversion, and session management |
| **Cross-Process Relay** | [`App/Relay`](App/Relay), [`Shared/Relay`](Shared/Relay) | Inter-process state machine, locking, and request routing |
| **Keyboard Extension** | [`KeyboardExtension`](KeyboardExtension) | Keyboard view controller, voice toolbar, and keycap layout |
| **Shared State & Models** | [`Shared`](Shared) | Speech engine modes, design theme, and shared data types |

---

## Getting Started

### Prerequisites
- macOS with **Xcode 26** or later (iOS 26+ SDK)
- An Apple Silicon Mac (recommended)
- iOS Simulator or a physical iPhone running iOS 26+
- *(Optional)* A Google Gemini API key (for cloud streaming and translation)
- *(Optional)* [XcodeGen](https://github.com/yonaskolb/XcodeGen) (if regenerating the `.xcodeproj`)

### 1. Build and Run Immediately
The project is pre-configured with ad-hoc signing for simulators. You do **not** need a paid Apple Developer account to build and run the sample:

Open `GeminiVoiceKeyboard.xcodeproj` in Xcode, select the **GeminiVoice** scheme with an **iPhone 17** simulator, and press **Cmd + R**.

### 2. Configure Your API Key
You can configure your Gemini API key in two ways:
- **Directly In-App (Recommended)**: Open the app on your device or simulator, navigate to **Settings → Gemini API Key**, and paste your key. It is saved directly to your device's secure iOS Keychain.
- **Via Configuration File**: Copy the template and add your credentials:
  ```sh
  cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
  ```
  Edit `Config/Secrets.xcconfig` with your Apple Team ID, Bundle Identifiers, and `GEMINI_DEFAULT_API_KEY`.

### 3. Run Automated Tests
Execute the comprehensive test suite (185 unit and UI tests):

```sh
./Scripts/test.sh -u    # Run fast unit tests
./Scripts/test.sh       # Run full suite (unit + UI tests)
```

### 4. Enable the Keyboard on Device
1. On your iPhone, navigate to **Settings → General → Keyboard → Keyboards → Add New Keyboard…**
2. Select **Gemini Voice**.
3. Tap **Gemini Voice** and toggle **Allow Full Access** (required for App Group communication with the containing app).
4. Open the **Gemini Voice** app once to grant microphone permissions.
5. In any text field, switch to Gemini Voice and tap **Dictate**!

---

## Behavior & Architecture Notes

- **Warm Relay**: The containing app keeps its audio session armed briefly in the background, allowing the keyboard to start dictation immediately without app switching.
- **Cold Relay Handoff**: If the containing app is terminated, the keyboard prompts a quick tap to open the app, automatically arming the microphone and returning focus.
- **Finish vs. Cancel**: *Finish* drains all buffered speech and delivers the final formatted result. *Cancel* immediately aborts processing, deletes temporary recordings, and leaves the text field untouched.
- **Insertion Safety**: Results are only inserted into the active text field if the request ID and text document context still match when transcription completes, preventing stray insertions.

---

## Legal & Third-Party Notices

This project is licensed under the [Apache License 2.0](LICENSE).

Third-party dependencies, model weights, and APIs are used under their respective licenses:
- **KeyboardKit 9.9.1**: Copyright (c) 2016-2025 Daniel Saidi ([MIT License](THIRD_PARTY_NOTICES.md#1-keyboardkit-991)).
- **Gemma 4 LiteRT-LM**: Copyright (c) Google LLC ([Apache 2.0 License](THIRD_PARTY_NOTICES.md#2-google-gemma-4-litert-lm-model)), subject to the [Google Gemma Additional Terms of Use](https://ai.google.dev/gemma/terms) and [Gemma Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). Model weights are downloaded on-demand and are not bundled in this repository.
- **Google Gemini API**: Governed by the [Google APIs Terms of Service](https://developers.google.com/terms) and [Gemini API Terms](https://ai.google.dev/gemini-api/terms).

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for full notices and trademark disclaimers.
