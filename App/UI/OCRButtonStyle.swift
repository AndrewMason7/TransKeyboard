import SwiftUI

// FIX #2 (per Kyle & Marcus): Respect accessible contrast on pastel backgrounds
struct OCRButtonStyle: ButtonStyle {
  let color: Color
  var textColor: Color = .white

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .padding(.vertical, 12)
      .padding(.horizontal, 10)
      .background(color.opacity(configuration.isPressed ? 0.55 : 0.82))
      .foregroundStyle(textColor)
      .clipShape(.rect(cornerRadius: 12))
  }
}
