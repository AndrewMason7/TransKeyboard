import SwiftUI

struct KeyboardToolbarView: View {
  @ObservedObject var state: KeyboardToolbarState

  var body: some View {
    HStack(spacing: 6) {
      // Leading: Gemini Brand Button
      KeyboardBrandMarkButton(state: state)

      // Center: Dynamic Status / Waveform Pill
      KeyboardToolbarStatusPill(state: state)

      Spacer(minLength: 4)

      // Trailing Action Controls
      HStack(spacing: 6) {
        // Dictation / Microphone Button
        KeyboardToolbarActionButton(
          iconName: state.microphoneImage,
          backgroundColor: state.microphoneColor,
          foregroundColor: .white,
          isEnabled: state.isMicrophoneEnabled,
          accessibilityIdentifier: "keyboard-dictate-button",
          accessibilityLabel: state.microphoneAccessibilityLabel,
          accessibilityHint: state.microphoneAccessibilityHint,
          action: { state.onMicrophoneTap?() }
        )

        // Translation Button
        if !state.isTranslateHidden {
          KeyboardToolbarActionButton(
            iconName: state.translateImage,
            backgroundColor: state.translateColor,
            foregroundColor: .white,
            isEnabled: state.isTranslateEnabled,
            accessibilityIdentifier: "keyboard-translate-button",
            accessibilityLabel: state.translateAccessibilityLabel,
            accessibilityHint: state.translateAccessibilityHint,
            badgeText: state.targetLanguage.code.uppercased(),
            action: { state.onTranslateTap?() }
          )
        }

        // Cancel Button (Animated in/out)
        if !state.isCancelHidden {
          KeyboardToolbarActionButton(
            iconName: "xmark",
            backgroundColor: Color.red.opacity(0.88),
            foregroundColor: .white,
            isEnabled: state.isCancelEnabled,
            accessibilityIdentifier: "keyboard-cancel-button",
            accessibilityLabel: state.cancelAccessibilityLabel,
            accessibilityHint: state.cancelAccessibilityHint,
            action: { state.onCancelTap?() }
          )
          .transition(
            .asymmetric(
              insertion: .scale(scale: 0.6).combined(with: .opacity),
              removal: .scale(scale: 0.6).combined(with: .opacity)
            )
          )
        }
      }
    }
    .padding(.horizontal, 4)
    .frame(height: 40)
    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.isCancelHidden)
  }
}
