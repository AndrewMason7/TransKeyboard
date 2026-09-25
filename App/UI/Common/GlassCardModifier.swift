import SwiftUI

public struct GlassCardModifier: ViewModifier {
  public var cornerRadius: CGFloat
  public var padding: CGFloat

  public init(cornerRadius: CGFloat = 20, padding: CGFloat = 16) {
    self.cornerRadius = cornerRadius
    self.padding = padding
  }

  public func body(content: Content) -> some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.primary.opacity(0.06), lineWidth: 1)
      }
      .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
  }
}

extension View {
  public func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
    modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
  }
}
