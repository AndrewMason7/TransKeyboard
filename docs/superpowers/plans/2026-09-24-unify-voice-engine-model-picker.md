# Unify Voice Engine & Active Transcript Model into Single Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Combine the Voice Recognition Engine and Active Transcript Models into a single, unified picker that lists only the 3 explicit model names (`gemini-3.5-transcribe-live`, `gemini-3.5-transcribe`, `gemma-2b-it-q4.bin`), automatically setting the underlying pipeline and updating the telemetry card below it.

**Architecture:** 
1. Use `configuration.selectedModelId` as the single source of truth for the picker.
2. The single picker exposes only the 3 canonical model strings:
   - `gemini-3.5-transcribe-live` -> `.geminiLive`
   - `gemini-3.5-transcribe` -> `.geminiBatch`
   - `gemma-2b-it-q4.bin` -> `.localOnDevice`
3. Remove the redundant second model picker and standalone `ModelsInfoSection` from `SettingsView`.
4. Preserve `.accessibilityIdentifier("speech-engine-picker")` on the single picker and `.accessibilityIdentifier("active-transcription-model")` on the active model label so all UI tests pass.

**Tech Stack:** Swift 6.2, SwiftUI (iOS 27 SDK), Observation framework (`@Bindable`).

---

## Global Constraints
- Target device: **iPhone 17 only** (`platform=iOS Simulator,name=iPhone 17`, Physical UDID: `<DEVICE_UDID>`).
- Picker options: Show **only the model names** (`gemini-3.5-transcribe-live`, `gemini-3.5-transcribe`, `gemma-2b-it-q4.bin`).
- Exactly **one picker** in the section; remove duplicate model pickers.
- Two-stage verification: 100% green tests in simulator, followed by physical deployment.

---

## Proposed Changes

### Component 1: `AppConfiguration.swift` Model Constants
#### [MODIFY] `App/Application/AppConfiguration.swift`
- Add `public static let availableTranscriptionModels: [String] = ["gemini-3.5-transcribe-live", "gemini-3.5-transcribe", ModelDownloadManager.defaultModelFileName]`.
- Verify `selectedModelId` getter and setter cleanly map to `.geminiLive`, `.geminiBatch`, and `.localOnDevice`.

### Component 2: Unified `SpeechEngineSection.swift`
#### [MODIFY] `App/UI/Settings/SpeechEngineSection.swift`
- Single `.pickerStyle(.menu)` bound to `$configuration.selectedModelId`.
- Menu items show only the model names:
  ```swift
  ForEach(AppConfiguration.availableTranscriptionModels, id: \.self) { modelName in
    Text(modelName).tag(modelName)
  }
  ```
- Has `.accessibilityIdentifier("speech-engine-picker")`.
- Telemetry Hero Card displays:
  - Active model label with `.accessibilityIdentifier("active-transcription-model")`.
  - Icon + Category badge (`RECOMMENDED`, `BATCH`, `100% PRIVATE`).
  - Latency chip (`< 300ms`, `~1-2s`, `Real-time`).
  - Technical highlights.

### Component 3: `SettingsView.swift` Layout
#### [MODIFY] `App/UI/Settings/SettingsView.swift`
- Render only `SpeechEngineSection(configuration: configuration).glassCard(...)`.
- Eliminate the separate `ModelsInfoSection` card completely.

---

## Plan Tasks

- [ ] **Task 1: Update AppConfiguration with Canonical Model List**
  - Add `availableTranscriptionModels` constant.
  - Verify `selectedModelId` mapping.

- [ ] **Task 2: Refactor SpeechEngineSection to Single 3-Model Picker**
  - Bind to `$configuration.selectedModelId`.
  - Expose only the 3 model names.
  - Attach accessibility identifiers `speech-engine-picker` and `active-transcription-model`.

- [ ] **Task 3: Streamline SettingsView**
  - Remove redundant `ModelsInfoSection` from `SettingsView`.

- [ ] **Task 4: Automated Testing on iPhone 17 Simulator**
  - Execute full test suite via `mobilebuildmcp_mobilebuildmcp.test_sim`.
  - Verify all 157+ tests pass.

- [ ] **Task 5: Physical Device Deployment**
  - Deploy to connected iPhone 17 (`<DEVICE_UDID>`).
