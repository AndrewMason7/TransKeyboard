import SwiftUI

struct RecoverableRecordingCard: View {
  let recording: RecoverableRecording
  @Bindable var relay: RelayController
  let onDeleteRequest: (RecoverableRecording) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(recording.actionTitle, systemImage: "waveform.badge.exclamationmark")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)

        Spacer()

        Text(recording.createdAt, style: .relative)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      // Error message callout
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill")
          .foregroundStyle(.orange)
          .font(.caption)

        Text(recording.lastError)
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.orange.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

      // Actions row
      HStack(spacing: 10) {
        Button {
          relay.retryRecording(recording)
        } label: {
          HStack(spacing: 6) {
            if relay.retryingRecordingID == recording.id {
              ProgressView()
                .controlSize(.small)
                .tint(.white)
            } else {
              Image(systemName: "arrow.clockwise")
            }
            Text(
              recording.transcriptSaved == true
                ? "Transcript saved"
                : relay.retryingRecordingID == recording.id
                  ? "Retrying…"
                  : "Retry Transcription"
            )
          }
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 11)
          .background(GeminiVoiceTheme.accentColor)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(
          recording.transcriptSaved == true
            || relay.retryingRecordingID != nil
            || relay.status.isBusy
        )

        Button(role: .destructive) {
          onDeleteRequest(recording)
        } label: {
          Image(systemName: "trash")
            .font(.subheadline)
            .frame(width: 44, height: 44)
            .background(Color.red.opacity(0.12))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(relay.retryingRecordingID == recording.id)
        .accessibilityLabel("Delete saved recording")
      }
      .padding(.top, 2)
    }
    .glassCard(cornerRadius: 18, padding: 16)
  }
}
