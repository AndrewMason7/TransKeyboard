import PhotosUI
import SwiftUI
import UIKit

public enum AppTab: String, CaseIterable, Identifiable {
  case studio
  case history
  case settings

  public var id: String { rawValue }
}

struct ContentView: View {
  @Bindable var configuration: AppConfiguration
  @Bindable var relay: RelayController

  @State private var selectedTab: AppTab = .studio
  @State private var recordingPendingDeletion: RecoverableRecording?
  @State private var selectedPhotoItem: PhotosPickerItem?

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        StudioView(
          configuration: configuration,
          relay: relay,
          selectedPhotoItem: $selectedPhotoItem
        )
      }
      .tabItem {
        Label("Studio", systemImage: "waveform.circle.fill")
      }
      .tag(AppTab.studio)

      NavigationStack {
        HistoryView(
          relay: relay,
          recordingPendingDeletion: $recordingPendingDeletion
        )
      }
      .tabItem {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
      .tag(AppTab.history)

      NavigationStack {
        SettingsView(
          configuration: configuration,
          relay: relay
        )
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
      .tag(AppTab.settings)
    }
    .tint(GeminiVoiceTheme.accentColor)
    .overlay {
      if relay.isKeyboardHandoffActive {
        KeyboardHandoffOverlay(relay: relay)
      }
    }
    .onOpenURL(perform: relay.handleDeepLink)
    .sheet(
      isPresented: Binding(
        get: { relay.isImagePickerPresented },
        set: { presented in
          if !presented && relay.isImagePickerPresented {
            relay.imagePickerDidCancel()
          }
        }
      )
    ) {
      ImagePicker(
        sourceType: relay.imagePickerSource,
        onImage: relay.imagePickerDidSelect,
        onCancel: relay.imagePickerDidCancel
      )
      .ignoresSafeArea()
    }
    .confirmationDialog(
      "Delete this saved recording?",
      item: $recordingPendingDeletion,
      titleVisibility: .visible
    ) { recording in
      Button("Delete Recording", role: .destructive) {
        relay.deleteRecording(recording)
      }
      Button("Keep Recording", role: .cancel) {}
    } message: { _ in
      Text("This permanently removes the local audio clip.")
    }
    // FIX #7 (per Tyler & Maya): Structured task modifier scoped to photo selection lifecycle
    .task(id: selectedPhotoItem) {
      guard let selectedPhotoItem else { return }
      defer { self.selectedPhotoItem = nil }
      if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
         let image = UIImage(data: data) {
        relay.imagePickerDidSelect(image)
      }
    }
  }
}

#Preview {
  let configuration = AppConfiguration()
  ContentView(
    configuration: configuration,
    relay: RelayController(configuration: configuration)
  )
}
