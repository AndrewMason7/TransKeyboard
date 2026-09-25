import SwiftUI

struct SpeechEngineSection: View {
  @Bindable var configuration: AppConfiguration
  var downloadManager: ModelDownloadManager? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Card Header
      Label("Voice Recognition", systemImage: "waveform.badge.mic")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      // Full-Width Interactive Model Selector Menu
      modelSelectorMenu

      // Dynamic Telemetry Hero Card
      telemetryCard(for: configuration.speechEngineMode)

      // Inline Local Model Management
      if let downloadManager {
        Divider()
          .overlay(Color.primary.opacity(0.08))
          .padding(.vertical, 2)

        LocalGemmaSection(downloadManager: downloadManager)
      }
    }
  }

  // MARK: - Model Selector Menu (Full-Width, Single-Line, HIG-Compliant)

  private var modelSelectorMenu: some View {
    Menu {
      Picker("Voice Recognition Model", selection: $configuration.selectedModelId) {
        ForEach(AppConfiguration.availableTranscriptionModels, id: \.self) { modelName in
          Text(modelName).tag(modelName)
        }
      }
    } label: {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          Text("ACTIVE MODEL")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)

          Text(configuration.activeTranscriptionModelDisplay)
            .font(.subheadline.weight(.semibold).monospaced())
            .foregroundStyle(GeminiVoiceTheme.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("active-transcription-model")
            .accessibilityLabel("Active transcription model")
            .accessibilityValue(configuration.activeTranscriptionModelDisplay)
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.up.chevron.down")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color.primary.opacity(0.04))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(GeminiVoiceTheme.accentColor.opacity(0.3), lineWidth: 1)
      )
    }
    .accessibilityIdentifier("speech-engine-picker")
    .sensoryFeedback(.selection, trigger: configuration.selectedModelId)
  }

  // MARK: - Telemetry Hero Card

  @ViewBuilder
  private func telemetryCard(for mode: SpeechEngineMode) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // Top info row: Icon + Category Badge on left, unified Latency Pill on right
      HStack(alignment: .center) {
        HStack(spacing: 8) {
          ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(LinearGradient.geminiVoicePrimary)
              .frame(width: 32, height: 32)

            Image(systemName: mode.iconName)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(Color(red: 0.12, green: 0.1, blue: 0.18))
          }

          Text(mode.badgeText)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeBackgroundColor(for: mode))
            .foregroundStyle(badgeForegroundColor(for: mode))
            .clipShape(Capsule())
        }

        Spacer(minLength: 8)

        // Unified Single-line Latency Pill
        HStack(spacing: 4) {
          Image(systemName: "gauge.with.needle.fill")
            .font(.caption2)
            .foregroundStyle(GeminiVoiceTheme.accentColor)

          Text(mode.latencyEstimate)
            .font(.caption2.weight(.bold).monospaced())
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
      }

      // Subtitle summary
      Text(mode.subtitle)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)

      Divider()
        .overlay(Color.primary.opacity(0.08))

      // Capability bullets
      VStack(alignment: .leading, spacing: 6) {
        ForEach(mode.featureHighlights, id: \.self) { highlight in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(GeminiVoiceTheme.accentColor)
              .padding(.top, 2)

            Text(highlight)
              .font(.subheadline)
              .foregroundStyle(.primary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(14)
    .background(Color.primary.opacity(0.03))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    )
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: mode)
  }

  private func badgeBackgroundColor(for mode: SpeechEngineMode) -> Color {
    switch mode {
    case .geminiLive:
      return GeminiVoiceTheme.accentColor.opacity(0.18)
    case .geminiBatch:
      return Color.blue.opacity(0.15)
    case .localOnDevice:
      return Color.green.opacity(0.18)
    case .autoFallback:
      return Color.purple.opacity(0.18)
    }
  }

  private func badgeForegroundColor(for mode: SpeechEngineMode) -> Color {
    switch mode {
    case .geminiLive:
      return GeminiVoiceTheme.accentColor
    case .geminiBatch:
      return .blue
    case .localOnDevice:
      return .green
    case .autoFallback:
      return .purple
    }
  }
}
