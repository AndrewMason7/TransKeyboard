# Redesign Voice Recognition Engine Section Implementation Plan (Menu Picker Edition)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign and upgrade the Voice Recognition Engine section using a native iOS Menu Picker paired with a dynamic telemetry detail card showcasing engine badges, latency metrics, SF symbols, and technical capability highlights.

**Architecture:** 
1. Enrich `SpeechEngineMode` with visual and telemetry metadata (`iconName`, `badgeText`, `latencyEstimate`, `featureHighlights`).
2. Upgrade `SpeechEngineSection` with:
   - A modern `.pickerStyle(.menu)` selector where each item displays a rich `Label(mode.displayName, systemImage: mode.iconName)`.
   - A dynamic telemetry card directly below the picker that animates when selection changes, showing latency badges, privacy pills, and feature highlights.
3. Preserve `.accessibilityIdentifier("speech-engine-picker")` on the `Picker`.

**Tech Stack:** Swift 6.2, SwiftUI (iOS 27 SDK), Observation framework (`@Bindable`), SF Symbols 6, HIG Adaptive Themes.

---

## Global Constraints
- Target device: **iPhone 17 only** (`platform=iOS Simulator,name=iPhone 17`, Physical UDID: `<DEVICE_UDID>`).
- Picker UI: Must be a **native menu picker** (`.pickerStyle(.menu)`), not a horizontal segmented bar.
- Accessibility identifiers must remain intact: `speech-engine-picker` must be discoverable for automated tests.
- Two-stage verification sequence: 100% green tests in simulator, followed by physical deployment.

---

## Review Focus
1. **Menu Picker Ergonomics**: The menu picker must open seamlessly on iOS 17/27 with full titles and SF symbols without clipping.
2. **Dynamic Card Transitions**: Telemetry card must animate smoothly using `.contentTransition` and spring animations upon selection changes.
3. **Contrast Compliance**: Badges and text must pass WCAG 2.1 AA in both light and dark mode.
4. **Haptic Feedback**: Selection change must trigger native `.sensoryFeedback(.selection)`.

---

## Proposed Changes

### Component 1: Engine Mode Domain Metadata (`App/Application/SpeechEngineMode.swift`)
#### [MODIFY] `App/Application/SpeechEngineMode.swift`
- Add properties:
  - `iconName: String`: SF Symbol for each mode (`bolt.badge.automatic.fill`, `cloud.fill`, `lock.shield.fill`, `arrow.triangle.swap`).
  - `badgeText: String`: Short tag (`"RECOMMENDED"`, `"BATCH"`, `"100% PRIVATE"`, `"SMART HYBRID"`).
  - `latencyEstimate: String`: Runtime latency indicator (`"< 300ms"`, `"~1-2s"`, `"Real-time"`, `"Dynamic"`).
  - `featureHighlights: [String]`: Technical highlights for each engine.

### Component 2: Upgraded Voice Recognition Engine View (`App/UI/Settings/SpeechEngineSection.swift`)
#### [MODIFY] `App/UI/Settings/SpeechEngineSection.swift`
- Replace the segmented picker with:
  - Header row with section title & icon.
  - Native `.pickerStyle(.menu)` selector with `.accessibilityIdentifier("speech-engine-picker")`.
  - Dynamic telemetry hero card showing:
    - Selected mode's SF Symbol badge with twilight accent gradient.
    - Status pill & Latency pill.
    - Detailed description and feature bullet points.
  - Sensory haptic trigger on selection change.

### Component 3: Test Suite Updates
#### [MODIFY] `Tests/SpeechEngineModeTests.swift`
- Test `iconName`, `badgeText`, `latencyEstimate`, and `featureHighlights` for all cases.
#### [MODIFY] `Tests/SettingsTabTests.swift`
- Verify `SpeechEngineSection` renders with menu picker and telemetry card.

---

## Plan Tasks

- [ ] **Task 1: Enrich `SpeechEngineMode` with Presentation Metadata**
  - Add properties to `SpeechEngineMode.swift`.
  - Update unit tests in `Tests/SpeechEngineModeTests.swift`.

- [ ] **Task 2: Implement Upgraded Menu Picker & Dynamic Telemetry Card in `SpeechEngineSection.swift`**
  - Implement `.pickerStyle(.menu)` with SF Symbol labels.
  - Implement dynamic telemetry card with latency and privacy pills.
  - Retain `speech-engine-picker` accessibility identifier.

- [ ] **Task 3: Automated Testing & Verification on iPhone 17 Simulator**
  - Execute full test suite using `mobilebuildmcp_mobilebuildmcp.test_sim`.
  - Verify 156+ tests pass (100% green).

- [ ] **Task 4: Physical Device Deployment**
  - Deploy to connected iPhone 17 (`<DEVICE_UDID>`) and launch app.
