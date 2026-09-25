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
            color: backgroundColor.opacity(colorScheme == .dark ? 0.35 : 0.20),
            radius: 3,
            x: 0,
            y: 1
          )

        Image(systemName: iconName)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(foregroundColor)

        if let badgeText {
          Text(badgeText)
            .font(.system(size: 7.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color.black.opacity(0.65))
            .clipShape(Capsule())
            .overlay {
              Capsule()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
            }
            .offset(x: 9, y: 9)
        }
      }
      .frame(width: 30, height: 30)
      .frame(width: 34, height: 34)
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
