import UIKit

// Adapted for this sample from KeyboardKit 9.9.1 callout concepts.
// Copyright (c) 2016-2025 Daniel Saidi. MIT license; see THIRD_PARTY_NOTICES.md.

final class KeyboardInputCalloutView: UIView {
  private let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private let label = UILabel()
  private var calloutGeneration: UInt64 = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    clipsToBounds = false
    backgroundColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.28, alpha: 0.94)
        : UIColor(white: 1.0, alpha: 0.98)
    }
    layer.cornerRadius = 13
    layer.cornerCurve = .continuous
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.22
    layer.shadowRadius = 8
    layer.shadowOffset = CGSize(width: 0, height: 4)
    layer.borderWidth = 0.5
    layer.borderColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 1.0, alpha: 0.22)
        : UIColor(white: 1.0, alpha: 0.70)
    }.cgColor

    visualEffectView.layer.cornerRadius = 13
    visualEffectView.layer.cornerCurve = .continuous
    visualEffectView.clipsToBounds = true
    visualEffectView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(visualEffectView)

    label.font = .systemFont(ofSize: 32, weight: .regular)
    label.textAlignment = .center
    label.textColor = .label
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)

    NSLayoutConstraint.activate([
      visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      visualEffectView.topAnchor.constraint(equalTo: topAnchor),
      visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0 && bounds.height > 0 {
      layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(text: String, above key: UIView, in container: UIView) {
    calloutGeneration &+= 1
    layer.removeAllAnimations()
    label.text = text
    let isDark = container.effectiveIsDarkMode
    label.textColor = isDark ? .white : .black
    backgroundColor = isDark ? UIColor(white: 0.28, alpha: 0.96) : UIColor(white: 1.0, alpha: 0.98)
    layer.borderColor = isDark ? UIColor(white: 1.0, alpha: 0.20).cgColor : UIColor(white: 0.0, alpha: 0.12).cgColor

    let keyFrame = key.convert(key.bounds, to: container)
    let width = max(56, keyFrame.width + 18)
    let minX = width / 2 + 3
    let maxX = max(minX, container.bounds.width - width / 2 - 3)
    let centerX = min(max(keyFrame.midX, minX), maxX)
    let targetY = keyFrame.minY - 62
    let minYLimit = container.window != nil ? container.convert(CGPoint.zero, from: container.window).y + 2 : -56
    frame = CGRect(
      x: centerX - width / 2,
      y: max(minYLimit, targetY),
      width: width,
      height: 60
    )
    if superview !== container {
      removeFromSuperview()
      container.addSubview(self)
    }
    container.bringSubviewToFront(self)
    isHidden = false
    alpha = 1
  }

  func hide(animated: Bool = false) {
    let token = calloutGeneration
    if animated && !isHidden && alpha > 0 && window != nil {
      UIView.animate(
        withDuration: 0.10,
        delay: 0.05,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: { [weak self] in
          guard let self, self.calloutGeneration == token else { return }
          self.alpha = 0
        },
        completion: { [weak self] finished in
          guard let self, finished, self.calloutGeneration == token, self.alpha == 0 else { return }
          self.isHidden = true
        }
      )
    } else {
      calloutGeneration &+= 1
      layer.removeAllAnimations()
      isHidden = true
      alpha = 0
    }
  }
}

final class KeyboardAlternateCalloutView: UIView {
  private let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private let stack = UIStackView()
  private var labels: [UILabel] = []
  private(set) var selectedText: String?

  override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = false
    backgroundColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.24, alpha: 0.94)
        : UIColor(white: 1.0, alpha: 0.98)
    }
    layer.cornerRadius = 14
    layer.cornerCurve = .continuous
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.25
    layer.shadowRadius = 10
    layer.shadowOffset = CGSize(width: 0, height: 4)
    layer.borderWidth = 0.5
    layer.borderColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 1.0, alpha: 0.22)
        : UIColor(white: 1.0, alpha: 0.70)
    }.cgColor

    visualEffectView.layer.cornerRadius = 14
    visualEffectView.layer.cornerCurve = .continuous
    visualEffectView.clipsToBounds = true
    visualEffectView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(visualEffectView)

    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 3
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    NSLayoutConstraint.activate([
      visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      visualEffectView.topAnchor.constraint(equalTo: topAnchor),
      visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0 && bounds.height > 0 {
      layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(
    options: [String],
    above key: UIView,
    in container: UIView,
    anchoredToTrailingEdge: Bool
  ) {
    guard !options.isEmpty else { return }

    // Re-use existing labels from stack to prevent allocation churn
    while labels.count < options.count {
      let label = UILabel()
      label.textAlignment = .center
      label.textColor = .label
      label.font = .systemFont(ofSize: 22, weight: .medium)
      label.layer.cornerRadius = 9
      label.layer.cornerCurve = .continuous
      label.clipsToBounds = true
      stack.addArrangedSubview(label)
      labels.append(label)
    }

    for (index, label) in labels.enumerated() {
      if index < options.count {
        label.text = options[index]
        label.isHidden = false
      } else {
        label.isHidden = true
      }
    }

    let keyFrame = key.convert(key.bounds, to: container)
    let width = min(container.bounds.width - 8, max(60, CGFloat(options.count) * 38 + 10))
    let idealX = anchoredToTrailingEdge ? keyFrame.maxX - width : keyFrame.minX
    let x = min(max(idealX, 4), max(4, container.bounds.width - width - 4))
    let targetY = keyFrame.minY - 56
    let minYLimit = container.window != nil ? container.convert(CGPoint.zero, from: container.window).y + 2 : -56
    frame = CGRect(
      x: x,
      y: max(minYLimit, targetY),
      width: width,
      height: 52
    )
    if superview !== container {
      removeFromSuperview()
      container.addSubview(self)
    }
    container.bringSubviewToFront(self)
    isHidden = false
    alpha = 1
    select(index: anchoredToTrailingEdge ? options.count - 1 : 0, options: options)
  }

  func updateSelection(at point: CGPoint, options: [String]) {
    guard !options.isEmpty, bounds.width > 0 else { return }
    let localPoint = convert(point, from: superview)
    guard localPoint.x.isFinite, !localPoint.x.isNaN else { return }
    let count = CGFloat(options.count)
    guard count > 0 else { return }
    let itemWidth = bounds.width / count
    guard itemWidth.isFinite, itemWidth > 0 else { return }
    let rawIndex = Int(floor(localPoint.x / itemWidth))
    let index = min(options.count - 1, max(0, rawIndex))
    select(index: index, options: options)
  }

  func hide() {
    selectedText = nil
    isHidden = true
  }

  private func select(index: Int, options: [String]) {
    guard options.indices.contains(index), labels.indices.contains(index) else { return }
    selectedText = options[index]
    let selectedBg = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 1.0, alpha: 0.24)
        : UIColor(white: 0.0, alpha: 0.12)
    }
    let selectedTextColor = UIColor { traits in
      traits.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
    }
    for (labelIndex, label) in labels.enumerated() {
      let isSelected = labelIndex == index
      label.backgroundColor = isSelected ? selectedBg : .clear
      label.textColor = isSelected ? selectedTextColor : .secondaryLabel
    }
  }
}

extension UIView {
  var effectiveIsDarkMode: Bool {
    if traitCollection.userInterfaceStyle == .dark { return true }
    if traitCollection.userInterfaceStyle == .light { return false }
    if let windowStyle = window?.traitCollection.userInterfaceStyle, windowStyle != .unspecified {
      return windowStyle == .dark
    }
    return true
  }
}
