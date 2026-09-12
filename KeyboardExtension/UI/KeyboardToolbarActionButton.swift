import SwiftUI

struct KeyboardToolbarActionButton: View {
  let iconName: String
  let backgroundColor: Color
  let foregroundColor: Color
  let isEnabled: Bool
  let accessibilityIdentifier: String
  let accessibilityLabel: String
  let accessibilityHint: String?
  var badgeText: String? = nil
  var isPulsing: Bool = false
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .fill(backgroundColor)
          .overlay {
            Circle()
              .strokeBorder(
                Color.white.opacity(colorScheme == .dark ? 0.28 : 0.45),
                lineWidth: 0.5
              )
          }
          .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.15),
            radius: 3,
            x: 0,
            y: 1.5
          )

        Image(systemName: iconName)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(foregroundColor)

        if let badgeText {
          Text(badgeText)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
            .offset(x: 10, y: 10)
        }
      }
      .frame(width: 34, height: 34)
      .frame(width: 40, height: 40)
      .contentShape(Rectangle())
    }
    .buttonStyle(ScaleButtonStyle())
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1.0 : 0.42)
    .accessibilityIdentifier(accessibilityIdentifier)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint ?? "")
  }
}
