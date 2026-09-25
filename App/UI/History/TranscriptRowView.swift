import SwiftUI
import UIKit

struct TranscriptRowView: View {
  let item: TranscriptHistoryItem
  let onDelete: () -> Void

  @State private var didCopy: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Header info row
      HStack {
        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2.weight(.medium))
          .foregroundStyle(.secondary)

        Spacer()

        // FIX #6 (per Raj & Karen): Use zero-allocation wordCount
        Text("\(item.wordCount) words")
          .font(.caption2.monospaced())
          .foregroundStyle(.tertiary)
      }

      // Transcript body text
      Text(item.text)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)

      // Actions row
      HStack(spacing: 12) {
        Spacer()

        // FIX #4 (per Maya & Tyler): Structured concurrency instead of GCD asyncAfter
        Button {
          UIPasteboard.general.string = item.text
          didCopy = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
            Text(didCopy ? "Copied" : "Copy")
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(didCopy ? .green : GeminiVoiceTheme.accentColor)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: didCopy)

        ShareLink(item: item.text) {
          HStack(spacing: 4) {
            Image(systemName: "square.and.arrow.up")
            Text("Share")
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(GeminiVoiceTheme.accentColor)
        }
        .buttonStyle(.plain)

        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete transcript")
      }
      .padding(.top, 4)
    }
    .glassCard(cornerRadius: 18, padding: 16)
    .contextMenu {
      Button {
        UIPasteboard.general.string = item.text
      } label: {
        Label("Copy", systemImage: "doc.on.doc")
      }
      ShareLink(item: item.text) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
      Button(role: .destructive, action: onDelete) {
        Label("Delete", systemImage: "trash")
      }
    }
    // FIX #4 (per Maya & Tyler): Automatically cancelled on view recycle/unmount
    .task(id: didCopy) {
      if didCopy {
        try? await Task.sleep(for: .seconds(1.5))
        didCopy = false
      }
    }
  }
}
