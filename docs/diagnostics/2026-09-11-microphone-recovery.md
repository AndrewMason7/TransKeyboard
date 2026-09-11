# Microphone recovery crash investigation

The connected iPhone's three GeminiVoice crash reports (September 10 at 19:51 and September 11 at 13:06 and 14:28, Eastern time) all show SIGABRT from an Objective-C exception in `AVAudioEngineImpl::InstallTapOnNode`. The first app frame is `AudioCaptureEngine.startEngine(using:)`, called by `start()` and `recover(reason:)` on the main queue. All reports are from version 0.1.0 (35).

The reports verify the failing operation, but do not include the exception's reason string. A stale audio format during route recovery is the likely cause: the old implementation retained the same engine across session deactivation, reactivation, and configuration fallback, then reused its output format to install a new tap. A positive sample rate alone does not establish compatibility with the current hardware. Apple's [input-node documentation](https://developer.apple.com/documentation/AVFAudio/AVAudioEngine/inputNode) calls for checking the hardware input format; the [input-node reference](https://developer.apple.com/documentation/avfaudio/avaudioinputnode) explains that the input node does not perform hardware format conversion.

The change creates a fresh engine after session activation on every configuration attempt, checks the input and output formats for compatibility, stops the engine before removing the tap, cancels queued recovery when starting, and ignores configuration notifications from retired engines. Invalid or changing formats become a normal setup error instead of reaching tap installation.

Validation:

- Full Debug Simulator test suite passed, including new stale-format and obsolete-engine-notification regression tests.
- Release Simulator build and static analysis passed.
- Ten consecutive Simulator launches remained alive, with the deliberate nonfatal validation diagnostic enabled.
- No new local crash reports appeared.
- Production runtime-trap audit passed; audio and handoff lifecycle paths were also inspected for forced unwraps and unsafe accesses.
- Signed device build succeeded and was installed under the existing bundle and App Group identifiers, preserving app data and credentials.
- Initial device launch was denied because the phone was locked. Physical microphone recovery and the complete keyboard round trip remain to be verified after unlock; Simulator checks cannot establish their reliability.

Crash report copies and build/test logs are in `/tmp/gv-device-crashes` and `/tmp/gv-*.log` on the development Mac. Raw device reports are not committed.
