import SwiftUI
import UIKit

struct StudioTestPlaygroundView: View {
  @Bindable var relay: RelayController
  @State private var testText: String = ""
  @State private var isTestActive: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("In-App Voice Playground", systemImage: "sparkles")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        if relay.status == .recording && isTestActive {
          HStack(spacing: 6) {
            Circle()
              .fill(.red)
              .frame(width: 8, height: 8)
              .symbolEffect(.pulse)
            Text("LIVE")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.red)
          }
        }
      }

      Text("Test speech-to-text and live translation directly inside the app without switching to another field.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      // Transcript display box
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.primary.opacity(0.04))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(Color.primary.opacity(0.08), lineWidth: 1)
          )

        if displayedText.isEmpty {
          if relay.status == .recording && isTestActive {
            HStack(spacing: 8) {
              ProgressView()
                .controlSize(.small)
              Text("Listening… speak into the microphone")
                .font(.subheadline)
                .foregroundStyle(GeminiVoiceTheme.accentColor)
            }
            .padding(14)
          } else if relay.status == .transcribing && isTestActive {
            HStack(spacing: 8) {
              ProgressView()
                .controlSize(.small)
              Text(relay.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(14)
          } else {
            Text("Tap 'Start Test Dictation' below and speak to test your microphone…")
              .font(.subheadline)
              .foregroundStyle(.secondary.opacity(0.7))
              .padding(14)
          }
        } else {
          ScrollView {
            Text(displayedText)
              .font(.subheadline)
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(14)
              .textSelection(.enabled)
          }
        }
      }
      .frame(minHeight: 88, maxHeight: 120)

      // Action buttons
      HStack(spacing: 10) {
        if (relay.status == .recording || relay.status == .transcribing) && isTestActive {
          Button {
            finishTestDictation()
          } label: {
            if relay.status == .transcribing {
              HStack(spacing: 6) {
                ProgressView()
                  .controlSize(.small)
                  .tint(.white)
                Text("Finalizing…")
                  .font(.subheadline.weight(.semibold))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.secondary.opacity(0.4))
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
              Label("Finish & Insert", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
          }
          .buttonStyle(.plain)
          .disabled(relay.status == .transcribing)

          Button {
            cancelTestDictation()
          } label: {
            Image(systemName: "xmark")
              .font(.subheadline.weight(.bold))
              .frame(width: 44, height: 44)
              .background(Color.primary.opacity(0.08))
              .foregroundStyle(.secondary)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
        } else {
          Button {
            startTestDictation()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "mic.badge.plus")
              Text("Start Test Dictation")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(GeminiVoiceTheme.accentColor.opacity(0.15))
            .foregroundStyle(GeminiVoiceTheme.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(relay.status == .recording || relay.status == .transcribing)

          if !displayedText.isEmpty {
            Button {
              UIPasteboard.general.string = displayedText
            } label: {
              Image(systemName: "doc.on.doc")
                .font(.subheadline)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.06))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy test transcript")
          }
        }
      }
    }
    .glassCard(cornerRadius: 22, padding: 18)
    .onChange(of: relay.status) { _, newStatus in
      if isTestActive && newStatus == .idle {
        isTestActive = false
        testText = relay.history.first?.text ?? ""
      } else if isTestActive && newStatus == .error {
        isTestActive = false
      }
    }
  }

  // FIX #H5.1 & #Jake.1 (per Jamie & Jake): Eliminate nested ternary soup with clean hierarchical branches
  private var displayedText: String {
    if relay.status == .recording {
      return relay.livePreviewText
    }
    if relay.status == .transcribing && isTestActive {
      if !relay.livePreviewText.isEmpty {
        return relay.livePreviewText
      }
      return testText.isEmpty ? relay.statusMessage : testText
    }
    if !testText.isEmpty {
      return testText
    }
    return isTestActive ? "" : (relay.history.first?.text ?? "")
  }

  // FIX #8 (per Jamie & Marcus): Verify relay readiness before committing test state
  private func startTestDictation() {
    testText = ""
    Task {
      if !relay.isRelayRunning {
        await relay.startRelay()
      }
      guard relay.isRelayRunning || relay.status == .idle else {
        isTestActive = false
        return
      }
      if relay.configuration.speechEngineMode == .appleSpeech || relay.configuration.speechEngineMode == .localOnDevice {
        _ = await LocalSpeechTranscriber.ensureAuthorized()
      }
      isTestActive = true
      let requestID = UUID().uuidString
      relay.beginDictation(requestID: requestID, action: .transcribe)
    }
  }

  private func finishTestDictation() {
    if let requestID = relay.activeRequestID {
      relay.finishDictationAndTranscribe(requestID: requestID)
    } else {
      isTestActive = false
    }
  }

  private func cancelTestDictation() {
    isTestActive = false
    relay.cancelDictation(message: "Test cancelled")
  }
}
