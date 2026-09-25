import SwiftUI

struct LocalGemmaSection: View {
  let downloadManager: ModelDownloadManager
  @State private var showingDeleteConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Local Gemma 4 E2B Model", systemImage: "cpu")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
        Spacer()
        if downloadManager.isModelReady {
          installedBadge
        }
      }

      Text("Optional local LiteRT-LM model for on-device punctuation formatting and offline translation (~2.5 GB).")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text("Provided under Apache 2.0. Subject to the [Google Gemma Terms of Use](https://ai.google.dev/gemma/terms).")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .tint(GeminiVoiceTheme.accentColor)
        .fixedSize(horizontal: false, vertical: true)

      downloadStatusContent
    }
  }

  @ViewBuilder
  private var downloadStatusContent: some View {
    switch downloadManager.state {
    case .notDownloaded:
      Button {
        downloadManager.startDownload()
      } label: {
        Label("Download Local Model", systemImage: "arrow.down.circle")
          .font(.caption.weight(.semibold))
      }
      .buttonStyle(.bordered)
      .tint(GeminiVoiceTheme.accentColor)
      .accessibilityIdentifier("download-local-model-button")

    case .downloading(let progress, let bytesWritten, let totalBytes):
      VStack(alignment: .leading, spacing: 6) {
        ProgressView(value: progress)
          .tint(GeminiVoiceTheme.accentColor)
        HStack {
          if totalBytes > 0 {
            Text("\(Int(progress * 100))% (\(bytesWritten.formatted(.byteCount(style: .file))) / \(totalBytes.formatted(.byteCount(style: .file))))")
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
          } else {
            Text("\(bytesWritten.formatted(.byteCount(style: .file))) downloaded")
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Cancel") {
            downloadManager.cancelDownload()
          }
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.red)
          .accessibilityIdentifier("cancel-model-download-button")
        }
      }

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
          Text("This will remove the downloaded Gemma 4 model from your device storage (~2.5 GB). You will need to re-download it to use local transcription.")
        }
      }

    case .failed(let message):
      VStack(alignment: .leading, spacing: 4) {
        Text("Error: \(message)")
          .font(.caption2)
          .foregroundStyle(.red)
        Button("Retry") {
          downloadManager.startDownload()
        }
        .font(.caption2.weight(.semibold))
        .tint(GeminiVoiceTheme.accentColor)
      }
    }
  }

  private var installedBadge: some View {
    Text("Installed")
      .font(.caption2.weight(.bold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.green.opacity(0.18))
      .foregroundStyle(.green)
      .clipShape(Capsule())
      .accessibilityIdentifier("local-model-installed-badge")
  }
}
