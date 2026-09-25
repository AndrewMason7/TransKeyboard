import SwiftUI
import UIKit

struct KeyboardSetupCard: View {
  @Environment(\.openURL) private var openURL
  @AppStorage("keyboard_setup_expanded") private var isExpanded: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("One-time setup", systemImage: "keyboard")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        Button {
          withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded.toggle()
          }
        } label: {
          HStack(spacing: 4) {
            Text(isExpanded ? "Collapse" : "Setup guide")
              .font(.caption.weight(.medium))
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption2.weight(.bold))
          }
          .foregroundStyle(GeminiVoiceTheme.accentColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(GeminiVoiceTheme.accentColor.opacity(0.12))
          .clipShape(Capsule())
        }
        .accessibilityIdentifier("keyboard-setup-toggle-button")
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          setupStep(1, "Open Settings › General › Keyboard › Keyboards.")
          setupStep(2, "Tap Add New Keyboard, then choose Gemini Voice.")
          setupStep(3, "Open Gemini Voice in the list and enable Allow Full Access.")
          setupStep(4, "Select this keyboard with the globe key in any text field.")

          Button("Open Gemini Voice Settings") {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(GeminiVoiceTheme.accentColor)
          .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      } else {
        Text("Keyboards › Gemini Voice › Allow Full Access. Tap guide to review.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .transition(.opacity)
      }
    }
    .glassCard(cornerRadius: 20, padding: 18)
  }

  private func setupStep(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(number)")
        .font(.caption2.bold())
        .frame(width: 22, height: 22)
        .background(GeminiVoiceTheme.accentColor.opacity(0.18))
        .foregroundStyle(GeminiVoiceTheme.accentColor)
        .clipShape(Circle())

      Text(text)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
  }
}
