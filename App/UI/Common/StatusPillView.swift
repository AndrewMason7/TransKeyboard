import SwiftUI

struct StatusPillView: View {
  let status: RelayStatus
  var isRelayRunning: Bool = false

  var body: some View {
    let color = GeminiVoiceTheme.statusColor(for: status)
    let title = GeminiVoiceTheme.statusTitle(for: status)

    HStack(spacing: 7) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
        .symbolEffect(.pulse, isActive: isRelayRunning || status == .recording)
      Text(title)
        .font(.caption2.weight(.bold))
        .foregroundStyle(color)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(color.opacity(0.12))
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(color.opacity(0.22), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Relay status: \(title)")
  }
}
