import SwiftUI

struct KeyboardBrandMarkButton: View {
  @ObservedObject var state: KeyboardToolbarState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button {
      state.onBrandTap?()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 11)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.25, green: 0.55, blue: 1.0),
                Color(red: 0.55, green: 0.35, blue: 0.95),
                Color(red: 0.85, green: 0.30, blue: 0.75),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay {
            RoundedRectangle(cornerRadius: 11)
              .strokeBorder(
                Color.white.opacity(colorScheme == .dark ? 0.35 : 0.45),
                lineWidth: 0.5
              )
          }
          .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15),
            radius: 3,
            x: 0,
            y: 1.5
          )

        Image(systemName: "sparkles")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(.white)
          .symbolRenderingMode(.hierarchical)
      }
      .frame(width: 34, height: 34)
      .frame(width: 40, height: 40)
      .contentShape(Rectangle())
    }
    .buttonStyle(ScaleButtonStyle())
    .accessibilityIdentifier("keyboard-brand-button")
    .accessibilityLabel("Gemini Voice")
    .accessibilityHint("Opens the Gemini Voice app")
  }
}
