import SwiftUI
import UIKit

extension KeyboardViewController {
  func buildInterface() {
    view.backgroundColor = .clear
    view.isOpaque = false


    let height = view.heightAnchor.constraint(
      equalToConstant: preferredKeyboardHeight
    )
    height.priority = .defaultHigh
    height.isActive = true
    keyboardHeightConstraint = height

    rootStack.axis = .vertical
    rootStack.alignment = .fill
    rootStack.spacing = 4
    rootStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(rootStack)

    NSLayoutConstraint.activate([
      rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
      rootStack.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
    ])

    let toolbar = makeToolbar()
    makeRecordingPanel()
    configureInsertLatestButton()

    typingStack.axis = .vertical
    typingStack.alignment = .fill
    typingStack.translatesAutoresizingMaskIntoConstraints = false
    keyboardSurface.translatesAutoresizingMaskIntoConstraints = false
    typingStack.addArrangedSubview(keyboardSurface)

    rootStack.addArrangedSubview(toolbar)
    rootStack.addArrangedSubview(insertLatestButton)
    rootStack.addArrangedSubview(recordingPanel)
    rootStack.addArrangedSubview(typingStack)

    toolbar.heightAnchor.constraint(equalToConstant: 40).isActive = true
    insertLatestButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
    insertLatestButton.isHidden = true
    recordingPanel.isHidden = true
  }

  var preferredKeyboardHeight: CGFloat {
    let contentHeight: CGFloat
    if traitCollection.horizontalSizeClass == .regular {
      contentHeight = 300
    } else if traitCollection.verticalSizeClass == .compact {
      contentHeight = 196
    } else {
      let isLargePhone = (view.window?.bounds.width ?? view.bounds.width) > 400
      contentHeight = isLargePhone ? 254 : 244
    }
    let resultBannerHeight: CGFloat = insertLatestButton.isHidden ? 0 : 45
    return contentHeight + resultBannerHeight + view.safeAreaInsets.bottom
  }

  func updateKeyboardHeight() {
    let height = preferredKeyboardHeight
    guard keyboardHeightConstraint?.constant != height else { return }
    keyboardHeightConstraint?.constant = height
  }

  func makeToolbar() -> UIView {
    if let previous = toolbarHostingController {
      previous.willMove(toParent: nil)
      previous.view.removeFromSuperview()
      previous.removeFromParent()
      toolbarHostingController = nil
    }

    toolbarState.onBrandTap = { [weak self] in
      self?.openContainingAppFromBrandMark()
    }
    toolbarState.onMicrophoneTap = { [weak self] in
      self?.microphoneTapped()
    }
    toolbarState.onTranslateTap = { [weak self] in
      self?.translateTapped()
    }
    toolbarState.onCancelTap = { [weak self] in
      self?.cancelTapped()
    }

    let hosting = UIHostingController(rootView: KeyboardToolbarView(state: toolbarState))
    hosting.view.backgroundColor = .clear
    hosting.view.isOpaque = false
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    addChild(hosting)
    hosting.didMove(toParent: self)
    toolbarHostingController = hosting
    return hosting.view
  }

  func configureInsertLatestButton() {
    var insertConfiguration = UIButton.Configuration.tinted()
    insertConfiguration.cornerStyle = .capsule
    insertConfiguration.baseBackgroundColor = .systemCyan
    insertConfiguration.baseForegroundColor = .systemCyan
    insertConfiguration.image = UIImage(systemName: "arrow.down.doc.fill")
    insertConfiguration.imagePadding = 7
    insertConfiguration.title = "Insert latest"
    insertLatestButton.configuration = insertConfiguration
    insertLatestButton.accessibilityLabel = "Insert the latest transcript"
    insertLatestButton.accessibilityIdentifier = "keyboard-insert-latest-button"
    insertLatestButton.addAction(
      UIAction { [weak self] _ in
        self?.insertLatestTapped()
      },
      for: .touchUpInside
    )
    insertLatestButton.translatesAutoresizingMaskIntoConstraints = false
    insertLatestButton.isHidden = true
    prepareActionButton(insertLatestButton)
  }

  func makeRecordingPanel() {
    if let previous = recordingHostingController {
      previous.willMove(toParent: nil)
      previous.view.removeFromSuperview()
      previous.removeFromParent()
      recordingHostingController = nil
    }
    recordingPanel.subviews.forEach { $0.removeFromSuperview() }
    recordingPanel.backgroundColor = .clear
    recordingPanel.isOpaque = false
    recordingPanel.accessibilityIdentifier = "keyboard-recording-panel"

    let hosting = UIHostingController(rootView: KeyboardRecordingCardView(state: recordingCardState))
    hosting.view.backgroundColor = .clear
    hosting.view.isOpaque = false
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    addChild(hosting)
    recordingPanel.addSubview(hosting.view)
    hosting.didMove(toParent: self)
    recordingHostingController = hosting

    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: recordingPanel.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: recordingPanel.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: recordingPanel.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: recordingPanel.bottomAnchor),
    ])
  }

  func prepareActionButton(_ button: KeyboardButton) {
    button.isExclusiveTouch = true
    button.accessibilityTraits.insert(.button)
    button.layer.cornerCurve = .continuous
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowRadius = 3
    button.layer.borderWidth = 0.5
    button.layer.borderColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 1.0, alpha: 0.22)
        : UIColor(white: 1.0, alpha: 0.45)
    }.cgColor
  }
}
