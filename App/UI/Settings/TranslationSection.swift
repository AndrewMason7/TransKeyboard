import SwiftUI

struct TranslationSection: View {
  @Bindable var configuration: AppConfiguration

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle(isOn: $configuration.isTranslationEnabled) {
        Label("Enable Translation", systemImage: "character.bubble.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
      }
      .tint(GeminiVoiceTheme.translationAccent)
      .accessibilityIdentifier("translation-feature-toggle")

      if configuration.isTranslationEnabled {
        HStack(spacing: 12) {
          Text("Output language")
            .font(.subheadline)
          Spacer(minLength: 8)
          Picker(
            "Output language",
            selection: $configuration.translationTargetCode
          ) {
            ForEach(TranslationLanguage.supported) { language in
              Text(language.name).tag(language.code)
            }
          }
          .pickerStyle(.menu)
          .tint(GeminiVoiceTheme.accentColor)
          .accessibilityIdentifier("translation-language-picker")
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Live translation model")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text(configuration.liveTranslationModel)
            .font(.caption.weight(.semibold).monospaced())
            .foregroundStyle(GeminiVoiceTheme.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("active-translation-model")
        .accessibilityLabel("Active translation model")
        .accessibilityValue(configuration.liveTranslationModel)

        Text("Multilingual dictation is translated into the selected output language.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "info.circle.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 1)

          Text("Translation button is removed from the keyboard. Dictation will transcribe speech in its original language.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("translation-disabled-note")
      }
    }
    .animation(.easeInOut(duration: 0.2), value: configuration.isTranslationEnabled)
  }
}
