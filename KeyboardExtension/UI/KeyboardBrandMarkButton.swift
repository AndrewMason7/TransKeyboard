import SwiftUI

struct KeyboardBrandMarkButton: View {
  var state: KeyboardToolbarState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button {
      state.onBrandTap?()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(LinearGradient.geminiVoicePrimary)
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(
                Color.white.opacity(colorScheme == .dark ? 0.35 : 0.50),
                lineWidth: 0.5
              )
          }
          .shadow(
            color: GeminiVoiceTheme.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20),
            radius: 3,
            x: 0,
            y: 1
          )

        Image(systemName: "sparkles")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
          .symbolRenderingMode(.hierarchical)
      }
      .frame(width: 30, height: 30)
      .frame(width: 34, height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(ScaleButtonStyle())
    .accessibilityIdentifier("keyboard-brand-button")
    .accessibilityLabel("Gemini Voice")
    .accessibilityHint("Opens the Gemini Voice app")
  }
}
