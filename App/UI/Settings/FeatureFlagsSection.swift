import SwiftUI

struct FeatureFlagsSection: View {
  @Bindable var store: FeatureFlagStore = .shared

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Feature Flags (Debug)", systemImage: "flag.2.crossed.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)

        Spacer()

        Button("Reset Defaults") {
          store.resetToDefaults()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("feature-flags-reset-button")
      }

      ForEach(FeatureFlagCategory.allCases) { category in
        categoryBlock(for: category)
      }
    }
  }

  private func categoryBlock(for category: FeatureFlagCategory) -> some View {
    let flags = FeatureFlag.allCases.filter { $0.category == category }
    return VStack(alignment: .leading, spacing: 10) {
      Label(category.rawValue, systemImage: category.systemImage)
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.top, 4)

      ForEach(flags) { flag in
        Toggle(isOn: Binding(
          get: { store[flag] },
          set: { store[flag] = $0 }
        )) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(flag.title)
                .font(.subheadline.weight(.medium))
              if store.hasOverride(flag) {
                Text("MODIFIED")
                  .font(.system(size: 9, weight: .bold))
                  .padding(.horizontal, 5)
                  .padding(.vertical, 1)
                  .background(Color.orange.opacity(0.18))
                  .foregroundStyle(.orange)
                  .clipShape(Capsule())
              }
            }
            Text(flag.subtitle)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .tint(GeminiVoiceTheme.accentColor)
        .accessibilityIdentifier("feature-flag-\(flag.rawValue)")
      }
    }
  }
}
