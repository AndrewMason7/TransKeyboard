import PhotosUI
import SwiftUI

struct StudioOCRCard: View {
  @Bindable var relay: RelayController
  @Binding var selectedPhotoItem: PhotosPickerItem?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Camera & Document OCR", systemImage: "viewfinder")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        if relay.isProcessingImage {
          ProgressView()
            .controlSize(.small)
            .tint(GeminiVoiceTheme.accentColor)
        }
      }

      Text(relay.ocrMessage)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        // FIX #2 (per Kyle & Marcus): Ensure high contrast text on pastel background
        Button {
          relay.startOCRCapture(preferCamera: true)
        } label: {
          Label("Take Photo", systemImage: "camera.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(
          OCRButtonStyle(
            color: Color(red: 193/255, green: 180/255, blue: 207/255),
            textColor: Color(red: 0.15, green: 0.1, blue: 0.2)
          )
        )
        .disabled(relay.isProcessingImage)
        .accessibilityIdentifier("camera-ocr-button")

        PhotosPicker(
          selection: $selectedPhotoItem,
          matching: .images,
          photoLibrary: .shared()
        ) {
          Label("Choose Image", systemImage: "photo.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(OCRButtonStyle(color: Color(red: 119/255, green: 155/255, blue: 218/255)))
        .foregroundStyle(.white)
        .disabled(relay.isProcessingImage)
      }
    }
    .glassCard(cornerRadius: 22, padding: 18)
  }
}
