import SwiftUI
import UIKit

struct CredentialsSection: View {
  @Bindable var configuration: AppConfiguration
  @State private var isEditing = false
  @State private var isRevealed = false
  @FocusState private var isFieldFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("API Credentials", systemImage: "key.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      HStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: isEditing ? "key.fill" : "lock.fill")
            .font(.subheadline)
            .foregroundStyle(isEditing ? GeminiVoiceTheme.accentColor : Color.primary.opacity(0.5))
            .frame(width: 20, height: 20)
            .contentTransition(.symbolEffect(.replace))

          if isEditing {
            if isRevealed {
              TextField("Optional API key override", text: $configuration.apiKeyOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .accessibilityIdentifier("api-key-field")
            } else {
              SecureField("Optional API key override", text: $configuration.apiKeyOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .accessibilityIdentifier("api-key-field")
            }
          } else {
            if configuration.apiKeyOverride.isEmpty {
              Text("Optional API key override")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("api-key-field")
            } else if isRevealed {
              Text(configuration.apiKeyOverride)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("api-key-field")
                .textSelection(.enabled)
            } else {
              Text("••••••••••••••••")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("api-key-field")
                .accessibilityLabel("Configured API key")
                .accessibilityValue("Hidden")
            }
          }

          Spacer(minLength: 0)

          // Show/Hide Reveal Eye Toggle with 44pt touch target and VoiceOver label
          if !configuration.apiKeyOverride.isEmpty {
            Button {
              withAnimation(.easeInOut(duration: 0.15)) {
                isRevealed.toggle()
              }
            } label: {
              Label(
                isRevealed ? "Hide API key" : "Show API key",
                systemImage: isRevealed ? "eye.slash" : "eye"
              )
              .labelStyle(.iconOnly)
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(isRevealed ? GeminiVoiceTheme.accentColor : .primary.opacity(0.65))
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
            }
            .accessibilityIdentifier("api-key-reveal-button")
          }

          // Paste from Clipboard Button with 44pt touch target and VoiceOver label
          if isEditing {
            Button {
              if let paste = UIPasteboard.general.string {
                configuration.apiKeyOverride = paste.trimmingCharacters(in: .whitespacesAndNewlines)
              }
            } label: {
              Label("Paste API key", systemImage: "doc.on.clipboard")
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(GeminiVoiceTheme.accentColor)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("api-key-paste-button")
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(isEditing ? GeminiVoiceTheme.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
        )

        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            if isEditing {
              isFieldFocused = false
              isEditing = false
              isRevealed = false
            } else {
              isEditing = true
              isFieldFocused = true
            }
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: isEditing ? "checkmark" : "pencil")
              .contentTransition(.symbolEffect(.replace))
            Text(isEditing ? "Done" : "Edit")
          }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 11)
          .background(isEditing ? GeminiVoiceTheme.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
          .foregroundStyle(isEditing ? GeminiVoiceTheme.accentColor : Color.primary)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityIdentifier("api-key-edit-button")
        .sensoryFeedback(.selection, trigger: isEditing)
      }

      // Credential Status Row & Conditional Clear Key Button
      HStack {
        Label(
          configuration.hasUsableAPIKey
            ? "Personal-device credential configured"
            : "API credential missing",
          systemImage: configuration.hasUsableAPIKey
            ? "checkmark.shield.fill"
            : "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(configuration.hasUsableAPIKey ? Color.green : Color.orange)

        Spacer()

        if !configuration.apiKeyOverride.isEmpty {
          Button("Clear key override") {
            configuration.clearAPIKeyOverride()
            if isEditing {
              isFieldFocused = false
              isEditing = false
              isRevealed = false
            }
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("api-key-clear-button")
        }
      }

      if let warning = configuration.credentialPersistenceWarning {
        Label(warning, systemImage: "key.slash.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }
}
