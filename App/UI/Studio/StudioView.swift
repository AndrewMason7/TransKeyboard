import PhotosUI
import SwiftUI

struct StudioView: View {
  @Bindable var configuration: AppConfiguration
  @Bindable var relay: RelayController
  @Binding var selectedPhotoItem: PhotosPickerItem?

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        brandHeader
        StudioRelayCard(configuration: configuration, relay: relay)
        StudioTestPlaygroundView(relay: relay)
        StudioOCRCard(relay: relay, selectedPhotoItem: $selectedPhotoItem)
      }
      .padding(.horizontal, 16)
      .padding(.top, 10)
      .padding(.bottom, 32)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .navigationTitle("Studio")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        StatusPillView(status: relay.status, isRelayRunning: relay.isRelayRunning)
      }
    }
  }

  private var brandHeader: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(LinearGradient.geminiVoicePrimary)
          .shadow(color: GeminiVoiceTheme.accentColor.opacity(0.3), radius: 10, x: 0, y: 4)

        Image("WaveformBadgeMic")
          .renderingMode(.template)
          .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.15))
          .opacity(relay.isRelayRunning ? 0.8 : 1.0)
      }
      .frame(width: 58, height: 58)

      VStack(alignment: .leading, spacing: 3) {
        Text("Gemini Voice")
          .font(.system(size: 26, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)

        Text("Dictation for every text field")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}
