import SwiftUI
import UIKit

extension ContentView {
  var settingsCard: some View {
    card {
      DisclosureGroup(isExpanded: $settingsExpanded) {
        VStack(alignment: .leading, spacing: 14) {
          Text(configuration.embeddedKeyDescription)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))

          Text(
            "Dictate and Translate always use Gemini Live while you speak. Finish inserts the final result; Cancel stops streaming and discards it. A temporary recording provides fallback if Live fails."
          )
          .font(.caption)
          .foregroundStyle(.white.opacity(0.55))
          .fixedSize(horizontal: false, vertical: true)

          HStack {
            Text("Live transcription model")
            Spacer(minLength: 8)
            Text(configuration.liveTranscriptionModel)
              .font(.caption.monospaced())
              .foregroundStyle(.cyan)
              .textSelection(.enabled)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityIdentifier("active-transcription-model")
          .accessibilityLabel("Active transcription model")
          .accessibilityValue(configuration.liveTranscriptionModel)

          HStack {
            Text("Fallback transcription model")
            Spacer(minLength: 8)
            Text(configuration.transcriptionModel)
              .font(.caption.monospaced())
              .foregroundStyle(.white.opacity(0.7))
              .textSelection(.enabled)
          }

          Divider()
            .overlay(Color.white.opacity(0.12))

          VStack(alignment: .leading, spacing: 3) {
            Label("Translate is always available", systemImage: "character.bubble.fill")
              .font(.subheadline.weight(.semibold))
            Text("The keyboard keeps Dictate, Translate, and Cancel visible as separate controls.")
              .font(.caption)
              .foregroundStyle(.white.opacity(0.55))
          }
          .accessibilityIdentifier("translation-always-available")

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
            .tint(.cyan)
            .accessibilityIdentifier("translation-language-picker")
          }

          HStack {
            Text("Live translation model")
            Spacer(minLength: 8)
            Text(configuration.liveTranslationModel)
              .font(.caption.monospaced())
              .foregroundStyle(.cyan)
              .textSelection(.enabled)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityIdentifier("active-translation-model")
          .accessibilityLabel("Active translation model")
          .accessibilityValue(configuration.liveTranslationModel)

          Text(
            "One completed dictation can contain multiple supported languages. They will all be translated into the selected output language."
          )
          .font(.caption)
          .foregroundStyle(.white.opacity(0.55))
          .fixedSize(horizontal: false, vertical: true)

          SecureField("Optional API key override", text: $configuration.apiKeyOverride)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(12)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityIdentifier("api-key-field")

          HStack {
            Label(
              configuration.hasUsableAPIKey
                ? "Personal-device credential configured"
                : "API credential missing",
              systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)

            Spacer()
            Button("Clear key override") {
              configuration.clearAPIKeyOverride()
            }
            .font(.caption.weight(.semibold))
          }

          if let warning = configuration.credentialPersistenceWarning {
            Label(warning, systemImage: "key.slash.fill")
              .font(.caption)
              .foregroundStyle(.orange)
          }
        }
        .padding(.top, 14)
      } label: {
        Label("Gemini settings", systemImage: "slider.horizontal.3")
          .font(.headline)
      }
      .tint(.white)
    }
  }
}
