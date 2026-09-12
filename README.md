# Gemini Voice Keyboard for iOS

An end-to-end iOS sample for Gemini 3.5 Live transcription and spoken translation from a custom keyboard. Tap **Dictate** or **Translate**, speak, tap again, and the result is inserted into the active text field.

> [!IMPORTANT]
> This is a personal developer sample, not a production SDK or an App Store-ready app. Its Debug-only cold handoff uses private iOS behavior for a smoother personal-device demo. Release compiles that behavior out.

## What it demonstrates

- `gemini-3.5-transcribe-live` streaming microphone audio and returning live text.
- `gemini-3.5-live-translate-preview` translating speech while it is spoken.
- A custom keyboard controlling microphone capture in its containing app through an App Group. Keyboard extensions cannot access the microphone themselves.
- Safe Finish, Cancel, fallback, recovery, and insertion into the original text field.
- A project-local typing surface adapted from KeyboardKit, with no runtime library dependency.

## Fork Enhancements & Modernization

This fork upgrades the sample to modern iOS standards with a redesigned voice toolbar and Apple-matching typing surface:

- **Native Apple Keyboard Geometry**: Compact keyboard height and tightened bottom padding so the bottom row keys (`123`, `space`, `.`, `return/search`) align cleanly right above the system globe and dictation microphone area.
- **Refined Keycap Aesthetics**: Dark theme `#424242` background, 8.5 pt rounded keycaps, zero borderlines, zero 3D shadows, and crisp high-contrast white glyphs.
- **Zero-Latency Typing**: Instantaneous case switching without crossfade lag, full multi-touch rollover, and touch-slop gesture handling to eliminate dropped keystrokes during rapid typing.
- **SwiftUI Voice Toolbar**: Floating voice control bar with reactive status pill, live audio waveform levels, tactile haptics, and accessible touch targets.
- **Hardened Architecture**: Full Swift 6 concurrency compliance, MainActor-isolated relay timer fixes, and an extensive unit test suite (103 passing tests across app and keyboard extension).

## Model routing

The keyboard voice buttons always start a Gemini Live session. There is no batch-mode toggle.

| Action | Primary model | Fallback |
| --- | --- | --- |
| **Dictate** | `gemini-3.5-transcribe-live` | `gemini-3.5-transcribe` after a Live failure |
| **Translate** | `gemini-3.5-live-translate-preview` | `gemini-3.5-transcribe` + `gemini-3.5-flash` after a Live failure |
| **Camera OCR** | `gemini-3.8-flash` | None |

The Flash models are never used for a normal keyboard voice request. They are limited to OCR and the emergency text-only translation step after Live has failed.

Model IDs and preview APIs change. Verify them against Google's [Live transcription](https://ai.google.dev/gemini-api/docs/live-api/live-transcribe), [Live translation](https://ai.google.dev/gemini-api/docs/live-api/live-translate), and [Gemini 3.8 Flash](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash) documentation before adopting the sample.

## How it works

```text
Custom keyboard
  │  start / finish / cancel + request ID
  ▼
Locked App Group store
  │
  ▼
Containing app microphone relay
  ├─ PCM stream → Gemini Live
  └─ protected WAV → fallback/retry only
  │
  ▼
Matching App Group result
  │
  ▼
UITextDocumentProxy.insertText
```

The important code is intentionally easy to find:

| Area | Location |
| --- | --- |
| Live model setup, streaming, events, and finalization | [`App/Gemini/Live`](App/Gemini/Live) |
| Batch fallback and OCR requests | [`App/Gemini/Batch`](App/Gemini/Batch) |
| Microphone capture and PCM conversion | [`App/Audio`](App/Audio) |
| App-side keyboard relay | [`App/Relay`](App/Relay) |
| Keyboard controller and UI | [`KeyboardExtension`](KeyboardExtension) |
| Cross-process request/result protocol | [`Shared/Relay`](Shared/Relay) |

For the detailed state machine and safety invariants, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). For a file-by-file Gemini guide, see [`App/Gemini/README.md`](App/Gemini/README.md).

## Requirements

- Xcode 26.6 or later
- iOS 26 or later
- A physical iPhone
- An Apple Developer team with three bundle identifiers and one shared App Group
- A Gemini API key for personal development
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Run the sample

1. Create the local configuration:

   ```sh
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

2. Add your Apple team, unique bundle identifiers, App Group, and Gemini API key to `Config/Secrets.xcconfig`.

3. Register the same identifiers and App Group in your Apple Developer account, then generate the project:

   ```sh
   xcodegen generate
   ```

4. Run the simulator test suite:

   ```sh
   ./Scripts/test.sh
   ```

5. Deploy to a paired iPhone:

   ```sh
   xcrun devicectl list devices
   ./Scripts/deploy-device.sh <device-identifier>
   ```

6. On the iPhone, add **Gemini Voice** under **Settings → General → Keyboard → Keyboards**, enable **Allow Full Access**, open the containing app once, and grant microphone access.

7. In any normal text field, select the keyboard and try **Dictate** or **Translate**. Tap the active button again to Finish; use **X** to discard.

## Behavior worth knowing

- **Warm relay is the intended path.** The containing app keeps its microphone session armed briefly in the background, so the keyboard can start immediately without leaving the text field.
- **Cold relay needs a handoff.** Release asks the user to return manually. The personal Debug build contains an unsupported automatic-return experiment.
- **Finish is not Cancel.** Finish drains accepted audio and waits for the authoritative final result. Cancel remains available while recording or processing; it stops the work, deletes the temporary recording, and inserts nothing.
- **Long recordings auto-finish at five minutes.** This bounds background and fallback resource use without interrupting normal dictation-length speech.
- **Fallback is explicit.** A complete local WAV is used only when Live fails after Finish. Failed recordings remain available for a user-initiated retry.
- **Insertion is guarded.** A result is inserted automatically only when its request and document anchor still match; otherwise the keyboard offers **Insert latest**.

## Security boundary

`Config/Secrets.xcconfig` is ignored by Git, but a Debug key compiled into an app is still extractable. Use a restricted development key with billing limits.

Production software should keep long-lived keys on a backend, proxy batch requests, and issue constrained [ephemeral tokens](https://ai.google.dev/gemini-api/docs/live-api/ephemeral-tokens) for direct Live connections. Review the included privacy manifests and make your own privacy disclosures.

## License

Licensed under the [Apache License 2.0](LICENSE). The local typing surface includes MIT-licensed KeyboardKit adaptations documented in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
