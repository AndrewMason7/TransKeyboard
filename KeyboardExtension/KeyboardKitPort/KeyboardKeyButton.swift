import UIKit

// Adapted for this sample from KeyboardKit 9.9.1 interaction and styling
// concepts. Copyright (c) 2016-2025 Daniel Saidi. MIT license; see
// THIRD_PARTY_NOTICES.md.

final class KeyboardKeyButton: UIButton {
  private(set) var key: KeyboardLayoutKey
  private var glassVisualEffectView: UIVisualEffectView?

  var isDarkMode: Bool {
    effectiveIsDarkMode
  }

  func currentForegroundColor(isSelectedShift: Bool) -> UIColor {
    if isSelectedShift { return .black }
    if glassVisualEffectView != nil { return .white }
    if key.style == .accent { return .white }
    return isDarkMode ? .white : .black
  }

  init(key: KeyboardLayoutKey) {
    self.key = key
    super.init(frame: .zero)
    isExclusiveTouch = false
    accessibilityTraits.insert(.keyboardKey)
    layer.cornerCurve = .continuous
    layer.cornerRadius = 8.5
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    setContentHuggingPriority(.defaultLow, for: .horizontal)

    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      let effectView = UIVisualEffectView(effect: glass)
      effectView.isUserInteractionEnabled = false
      effectView.layer.cornerCurve = .continuous
      effectView.layer.cornerRadius = 8.5
      effectView.clipsToBounds = true
      insertSubview(effectView, at: 0)
      glassVisualEffectView = effectView
      layer.borderWidth = 0
      layer.borderColor = UIColor.clear.cgColor
      layer.shadowColor = UIColor.clear.cgColor
      layer.shadowOffset = .zero
      layer.shadowRadius = 0
      layer.shadowOpacity = 0
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: KeyboardKeyButton, _) in
        button.updateAppearance(animated: false)
      }
    } else {
      layer.shadowColor = UIColor.black.cgColor
      layer.shadowRadius = 0
      layer.shadowOffset = CGSize(width: 0, height: 1.0)
      layer.shadowOpacity = isDarkMode ? 0.35 : 0.25
      layer.borderWidth = 0.5
    }

    tintColor = currentForegroundColor(isSelectedShift: false)
    updateAppearance(animated: false)
  }

  func updateKey(_ newKey: KeyboardLayoutKey) {
    self.key = newKey
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      updateAppearance(animated: false)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0 && bounds.height > 0 {
      if glassVisualEffectView == nil {
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
      } else {
        layer.shadowPath = nil
      }
      if let glassView = glassVisualEffectView {
        glassView.frame = bounds
        sendSubviewToBack(glassView)
      }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var isHighlighted: Bool {
    didSet { updateAppearance(animated: true) }
  }

  override var isSelected: Bool {
    didSet { updateAppearance(animated: false) }
  }

  override var isEnabled: Bool {
    didSet { updateAppearance(animated: false) }
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // Generous touch slop (6 pt horizontally, 8 pt vertically) ensures rapid
    // keystrokes and fast thumb swipes do not prematurely trigger touchDragExit
    // and cancel valid key taps before lift-off.
    bounds.insetBy(dx: -6, dy: -8).contains(point)
  }

  func configure(title: String?, systemImage: String?, accessibilityLabel: String) {
    let isSelectedShift = (key.action == .shift && isSelected)
    let fgColor = currentForegroundColor(isSelectedShift: isSelectedShift)

    var configuration = self.configuration ?? (
      glassVisualEffectView != nil ? UIButton.Configuration.plain() : UIButton.Configuration.filled()
    )
    configuration.title = title
    configuration.image = systemImage.flatMap { name in
      let pointSize: CGFloat = (name == "arrow.right" || name == "return") ? 17 : 18
      let weight: UIImage.SymbolWeight = (name == "magnifyingglass" || name == "arrow.right") ? .semibold : .medium
      let symbolConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
      return UIImage(systemName: name, withConfiguration: symbolConfig)
    }
    configuration.imagePlacement = .leading
    configuration.imagePadding = 3
    configuration.cornerStyle = .fixed
    configuration.background.cornerRadius = 8.5
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: 1,
      leading: 2,
      bottom: 1,
      trailing: 2
    )
    configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
      [weak self] attributes in
      var transformed = attributes
      let isPeriod = (title == ".")
      let fontSize: CGFloat = (self?.key.style == .input || isPeriod) ? (isPeriod ? 22.0 : 23.0) : 16.0
      let fontWeight: UIFont.Weight = self?.key.style == .accent ? .semibold : (isPeriod ? .bold : .regular)
      transformed[AttributeScopes.UIKitAttributes.FontAttribute.self] = .systemFont(
        ofSize: fontSize,
        weight: fontWeight
      )
      let isShift = (self?.key.action == .shift && (self?.isSelected ?? false))
      let color = self?.currentForegroundColor(isSelectedShift: isShift) ?? .white
      transformed[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] = color
      return transformed
    }
    configuration.imageColorTransformer = UIConfigurationColorTransformer { [weak self] _ in
      let isShift = (self?.key.action == .shift && (self?.isSelected ?? false))
      return self?.currentForegroundColor(isSelectedShift: isShift) ?? .white
    }

    configuration.baseForegroundColor = fgColor
    tintColor = fgColor

    if #available(iOS 26.0, *), glassVisualEffectView != nil {
      applyGlassStyling(to: &configuration, isSelectedShift: isSelectedShift)
    } else {
      configuration.baseBackgroundColor = resolveBackgroundColor(
        for: self.key.style,
        isPressed: self.isHighlighted,
        isSelected: isSelectedShift
      )
    }

    self.accessibilityLabel = accessibilityLabel
    let defaultShadowOpacity: Float = isDarkMode ? 0.35 : 0.25

    UIView.performWithoutAnimation {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      self.configuration = configuration
      if self.glassVisualEffectView != nil {
        self.layer.borderWidth = 0
        self.layer.borderColor = UIColor.clear.cgColor
        self.layer.shadowOpacity = 0
        self.layer.shadowColor = UIColor.clear.cgColor
        self.layer.shadowPath = nil
      } else {
        self.layer.borderWidth = 0.5
        self.layer.borderColor = Self.borderColor(
          for: self.key.style,
          isPressed: self.isHighlighted,
          isSelected: isSelectedShift
        ).cgColor
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = self.isHighlighted ? 0.04 : (isSelectedShift ? 0.30 : defaultShadowOpacity)
        self.layer.shadowOffset = self.isHighlighted ? CGSize(width: 0, height: 0.5) : CGSize(width: 0, height: 1.0)
        self.layer.shadowRadius = 0
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath
      }
      self.alpha = self.isEnabled ? 1.0 : 0.38
      self.transform = .identity
      self.layoutIfNeeded()
      self.removeAllContentAnimations()
      CATransaction.commit()
    }
  }

  func removeAllContentAnimations() {
    layer.removeAllAnimations()
    titleLabel?.layer.removeAllAnimations()
    imageView?.layer.removeAllAnimations()
    for subview in subviews {
      subview.layer.removeAllAnimations()
      for inner in subview.subviews {
        inner.layer.removeAllAnimations()
      }
    }
  }

  @available(iOS 26.0, *)
  private func applyGlassStyling(to configuration: inout UIButton.Configuration, isSelectedShift: Bool) {
    let glassEffect = glassVisualEffectView?.effect as? UIGlassEffect
    glassEffect?.tintColor = nil
    if isSelectedShift {
      configuration.background.backgroundColor = UIColor(white: 1.0, alpha: 0.95)
    } else {
      switch key.style {
      case .input, .system:
        let normalColor = UIColor(red: 0.259, green: 0.259, blue: 0.259, alpha: 1.0)
        let subtleWhitePressed = isDarkMode ? UIColor(white: 0.42, alpha: 1.0) : UIColor(white: 0.85, alpha: 1.0)
        configuration.background.backgroundColor = isHighlighted ? subtleWhitePressed : normalColor
      case .accent:
        configuration.background.backgroundColor = isHighlighted
          ? UIColor(red: 0.0, green: 0.40, blue: 0.90, alpha: 1.0)
          : UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
      }
    }
    layer.borderWidth = 0
    layer.borderColor = UIColor.clear.cgColor
    layer.shadowOpacity = 0
    layer.shadowColor = UIColor.clear.cgColor
    layer.shadowOffset = .zero
    layer.shadowRadius = 0
  }

  private func resolveBackgroundColor(
    for style: KeyboardKeyStyle,
    isPressed: Bool,
    isSelected: Bool
  ) -> UIColor {
    Self.backgroundColor(for: style, isPressed: isPressed, isSelected: isSelected)
  }

  func updateAppearance(animated: Bool) {
    let isSelectedShift = (key.action == .shift && isSelected)
    let fgColor = currentForegroundColor(isSelectedShift: isSelectedShift)
    tintColor = fgColor

    let changes = {
      var config = self.configuration
      config?.baseForegroundColor = fgColor
      if #available(iOS 26.0, *), self.glassVisualEffectView != nil {
        if var validConfig = config {
          self.applyGlassStyling(to: &validConfig, isSelectedShift: isSelectedShift)
          config = validConfig
        }
      } else {
        config?.baseBackgroundColor = self.resolveBackgroundColor(
          for: self.key.style,
          isPressed: self.isHighlighted,
          isSelected: isSelectedShift
        )
        let defaultShadowOpacity: Float = self.isDarkMode ? 0.35 : 0.25
        self.layer.borderWidth = 0.5
        self.layer.borderColor = Self.borderColor(
          for: self.key.style,
          isPressed: self.isHighlighted,
          isSelected: isSelectedShift
        ).cgColor
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = self.isHighlighted ? 0.04 : (isSelectedShift ? 0.30 : defaultShadowOpacity)
        self.layer.shadowOffset = self.isHighlighted ? CGSize(width: 0, height: 0.5) : CGSize(width: 0, height: 1.0)
      }
      self.configuration = config
      self.alpha = self.isEnabled ? 1.0 : 0.38
      self.transform = .identity
    }
    if animated {
      UIView.animate(
        springDuration: isHighlighted ? 0.06 : 0.14,
        bounce: 0,
        initialSpringVelocity: 0,
        delay: 0,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: changes
      )
    } else {
      UIView.performWithoutAnimation {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        self.layoutIfNeeded()
        self.removeAllContentAnimations()
        CATransaction.commit()
      }
    }
  }

  private static let foregroundColor = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
  }

  private static func backgroundColor(
    for style: KeyboardKeyStyle,
    isPressed: Bool,
    isSelected: Bool = false
  ) -> UIColor {
    if isSelected {
      return UIColor(white: 1.0, alpha: 0.98)
    }
    switch style {
    case .input, .system:
      return UIColor { traits in
        if traits.userInterfaceStyle == .dark {
          return UIColor(red: 0.259, green: 0.259, blue: 0.259, alpha: 1.0)
        } else {
          return isPressed
            ? UIColor(white: 0.95, alpha: 1.0)
            : UIColor(red: 172 / 255, green: 177 / 255, blue: 185 / 255, alpha: 0.95)
        }
      }
    case .accent:
      return isPressed ? UIColor.systemBlue.withAlphaComponent(0.80) : UIColor.systemBlue
    }
  }

  private static func borderColor(
    for style: KeyboardKeyStyle,
    isPressed: Bool,
    isSelected: Bool = false
  ) -> UIColor {
    if isSelected {
      return UIColor(white: 0.0, alpha: 0.15)
    }
    return UIColor { traits in
      if traits.userInterfaceStyle == .dark {
        return isPressed
          ? UIColor(white: 1.0, alpha: 0.22)
          : UIColor(white: 1.0, alpha: 0.12)
      } else {
        return isPressed
          ? UIColor(white: 0.0, alpha: 0.15)
          : UIColor(white: 0.0, alpha: 0.10)
      }
    }
  }
}
