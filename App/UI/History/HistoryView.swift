import SwiftUI

enum HistoryTabSection: String, CaseIterable, Identifiable {
  case transcripts = "Transcripts"
  case savedClips = "Saved Clips"

  var id: String { rawValue }
}

struct HistoryView: View {
  @Bindable var relay: RelayController
  @Binding var recordingPendingDeletion: RecoverableRecording?

  @State private var selectedSection: HistoryTabSection = .transcripts
  @State private var searchQuery: String = ""
  // FIX #1 (per Tom & Jamie): Protect user transcripts against accidental wipeout
  @State private var showClearConfirmation: Bool = false

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Segmented filter picker
        Picker("History Section", selection: $selectedSection) {
          Text("Transcripts (\(filteredTranscripts.count))")
            .tag(HistoryTabSection.transcripts)

          Text("Saved Clips (\(relay.recoverableRecordings.count))")
            .tag(HistoryTabSection.savedClips)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
        .padding(.top, 6)

        switch selectedSection {
        case .transcripts:
          transcriptsContent
        case .savedClips:
          savedClipsContent
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 32)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .navigationTitle("History")
    .searchable(text: $searchQuery, prompt: "Search transcripts…")
    .toolbar {
      if selectedSection == .transcripts && !relay.history.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Clear All") {
            showClearConfirmation = true
          }
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
        }
      }
    }
    .confirmationDialog(
      "Clear All Transcripts?",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear History", role: .destructive) {
        relay.clearHistory()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This permanently deletes all saved dictations and translations.")
    }
  }

  @ViewBuilder
  private var transcriptsContent: some View {
    if filteredTranscripts.isEmpty {
      if searchQuery.isEmpty {
        ContentUnavailableView(
          "No Transcripts Yet",
          systemImage: "text.quote",
          description: Text("Dictations and translations from your keyboard will appear here.")
        )
        .padding(.top, 40)
      } else {
        ContentUnavailableView.search(text: searchQuery)
          .padding(.top, 40)
      }
    } else {
      LazyVStack(spacing: 12) {
        ForEach(filteredTranscripts) { item in
          TranscriptRowView(item: item) {
            deleteTranscript(item)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var savedClipsContent: some View {
    if relay.recoverableRecordings.isEmpty {
      ContentUnavailableView(
        "No Pending Clips",
        systemImage: "waveform.badge.checkmark",
        description: Text("All audio recordings finished transcribing successfully.")
      )
      .padding(.top, 40)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        Text("These audio clips were interrupted before finishing. They remain stored safely on device until retried or deleted.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)

        LazyVStack(spacing: 12) {
          ForEach(relay.recoverableRecordings) { recording in
            RecoverableRecordingCard(
              recording: recording,
              relay: relay,
              onDeleteRequest: { rec in
                recordingPendingDeletion = rec
              }
            )
          }
        }
      }
    }
  }

  private var filteredTranscripts: [TranscriptHistoryItem] {
    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return relay.history
    }
    return relay.history.filter {
      $0.text.localizedCaseInsensitiveContains(searchQuery)
    }
  }

  private func deleteTranscript(_ item: TranscriptHistoryItem) {
    relay.deleteHistoryItem(id: item.id)
  }
}
