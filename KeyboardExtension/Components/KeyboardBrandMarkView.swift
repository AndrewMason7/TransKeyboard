import UIKit

final class KeyboardBrandMarkView: UIView {
  private let gradientLayer = CAGradientLayer()
  private let iconView = UIImageView(
    image: UIImage(
      systemName: "waveform", withConfiguration: UIImage.SymbolConfiguration(weight: .bold))
  )

  /// Invoked on a tap. The keyboard uses it to open the containing app.
  var tapHandler: (() -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)

    isUserInteractionEnabled = true
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tap)

    gradientLayer.colors = [
      UIColor.systemCyan.cgColor,
      UIColor.systemBlue.cgColor,
      UIColor.systemPurple.cgColor,
    ]
    gradientLayer.startPoint = CGPoint(x: 0, y: 0)
    gradientLayer.endPoint = CGPoint(x: 1, y: 1)
    gradientLayer.borderWidth = 1.5
    gradientLayer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
    layer.insertSublayer(gradientLayer, at: 0)

    iconView.tintColor = .white
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(iconView)
    NSLayoutConstraint.activate([
      iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
      iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 22),
      iconView.heightAnchor.constraint(equalToConstant: 22),
    ])

    isAccessibilityElement = true
    accessibilityLabel = "Gemini Voice"
    accessibilityTraits = .button
    accessibilityHint = "Opens the Gemini Voice app"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    return nil
  }

  @objc private func handleTap() {
    tapHandler?()
  }

  private var isPressed = false

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    setPressed(true)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    if let touch = touches.first {
      let location = touch.location(in: self)
      setPressed(bounds.contains(location))
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    setPressed(false)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    setPressed(false)
  }

  private func setPressed(_ pressed: Bool) {
    guard isPressed != pressed else { return }
    isPressed = pressed
    UIView.animate(withDuration: pressed ? 0.05 : 0.15) {
      self.alpha = pressed ? 0.6 : 1
      self.transform = pressed ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
    let cornerRadius = min(bounds.width, bounds.height) * 0.32
    gradientLayer.cornerRadius = cornerRadius
    if bounds.width > 0 && bounds.height > 0 {
      layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
  }

  func setStatus(_ text: String, accentColor: UIColor) {
    accessibilityValue = text
    layer.shadowColor = accentColor.cgColor
    layer.shadowOpacity = 0.24
    layer.shadowRadius = 5
    layer.shadowOffset = .zero
  }
}
