import SwiftUI

struct MiniWaveformIndicator: View {
  var level: CGFloat

  private static let multipliers: [CGFloat] = [0.55, 1.0, 0.75, 0.45]

  var body: some View {
    let safeLevel: CGFloat = (level.isFinite && !level.isNaN) ? max(0.0, min(1.0, level)) : 0.0
    HStack(alignment: .center, spacing: 2) {
      ForEach(0..<Self.multipliers.count, id: \.self) { index in
        let factor = Self.multipliers[index]
        let height = safeLevel * 9.0 * factor + 3.0
        Capsule()
          .fill(Color.red)
          .frame(width: 2.5, height: height)
      }
    }
    .animation(.easeOut(duration: 0.1), value: safeLevel)
  }
}
