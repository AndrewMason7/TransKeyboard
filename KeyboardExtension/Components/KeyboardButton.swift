import UIKit

final class KeyboardButton: UIButton {
  var expandsHitTarget = true

  override var isHighlighted: Bool {
    didSet { updateInteractionAppearance(animated: true) }
  }

  override var isEnabled: Bool {
    didSet { updateInteractionAppearance(animated: false) }
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    guard expandsHitTarget else { return super.point(inside: point, with: event) }
    return bounds.insetBy(dx: -3, dy: -3).contains(point)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.shadowColor = UIColor.black.cgColor
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    layer.shadowColor = UIColor.black.cgColor
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0 && bounds.height > 0 {
      let isCapsule = configuration?.cornerStyle == .capsule
      let radius = isCapsule ? bounds.height / 2 : (layer.cornerRadius > 0 ? layer.cornerRadius : 10)
      if isCapsule && layer.cornerRadius != radius {
        layer.cornerRadius = radius
      }
      layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }
  }

  private func updateInteractionAppearance(animated: Bool) {
    let changes = {
      self.alpha = self.isEnabled ? (self.isHighlighted ? 0.85 : 1.0) : 0.38
      self.transform =
        self.isHighlighted
        ? CGAffineTransform(scaleX: 0.94, y: 0.94)
        : .identity
      self.layer.shadowOpacity = self.isHighlighted ? 0.04 : 0.16
      self.layer.shadowOffset =
        self.isHighlighted
        ? CGSize(width: 0, height: 0.5)
        : CGSize(width: 0, height: 1.5)
    }

    if animated {
      UIView.animate(
        springDuration: isHighlighted ? 0.08 : 0.18,
        bounce: isHighlighted ? 0.0 : 0.24,
        initialSpringVelocity: 0,
        delay: 0,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: changes
      )
    } else {
      changes()
    }
  }
}
