import UIKit

// This source ports the small subset of KeyboardKit 9.9.1 behavior that this
// sample needs, while keeping the implementation local and editable.
// Copyright (c) 2016-2025 Daniel Saidi. MIT license; see THIRD_PARTY_NOTICES.md.

@MainActor
protocol KeyboardSurfaceViewDelegate: AnyObject {
  func keyboardSurface(_ surface: KeyboardSurfaceView, insertText text: String)
  func keyboardSurfaceDeleteBackward(_ surface: KeyboardSurfaceView)
  func keyboardSurface(_ surface: KeyboardSurfaceView, adjustTextPositionBy offset: Int)
  func keyboardSurfacePlayInputClick(_ surface: KeyboardSurfaceView)
  func keyboardSurface(
    _ surface: KeyboardSurfaceView,
    showInputModeListFrom button: UIButton,
    event: UIEvent
  )
}

final class KeyboardSurfaceView: UIView, UIGestureRecognizerDelegate {
  weak var delegate: KeyboardSurfaceViewDelegate?

  private(set) var interactionState = KeyboardInteractionState()
  private(set) var inputKind: KeyboardInputKind = .standard
  private(set) var needsInputModeSwitchKey = true
  private(set) var returnKeyType: UIReturnKeyType = .default

  private let rootStack = UIStackView()
  private let inputCallout = KeyboardInputCalloutView()
  private let alternateCallout = KeyboardAlternateCalloutView()
  private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
  private var rowButtons: [[KeyboardKeyButton]] = []
  private var deleteDelayTimer: Timer?
  private var deleteRepeatTimer: Timer?
  private var isDeleting = false
  private var longPressOptions: [ObjectIdentifier: [String]] = [:]
  private var activeLongPressOptions: [String] = []
  private var spaceDidMove = false
  private var lastSpaceStep = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = false
    rootStack.axis = .vertical
    rootStack.alignment = .fill
    rootStack.distribution = .fillEqually
    rootStack.spacing = 11
    rootStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(rootStack)
    let fillWidth = rootStack.widthAnchor.constraint(equalTo: widthAnchor, constant: -8)
    // UIInputViewController asks its content for a compressed fitting size before
    // the extension receives its final bounds. The row containers have no
    // intrinsic width, so a 750-priority fill constraint can be discarded during
    // that pass and leave the complete key grid collapsed around its center.
    // Keep the 760-point iPad cap required, but make filling every narrower host
    // width effectively mandatory.
    fillWidth.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([
      rootStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
      rootStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
      rootStack.centerXAnchor.constraint(equalTo: centerXAnchor),
      rootStack.widthAnchor.constraint(lessThanOrEqualToConstant: 760),
      fillWidth,
      rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
    ])

    registerForTraitChanges(
      [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    ) { (view: KeyboardSurfaceView, previousTraitCollection: UITraitCollection) in
      if previousTraitCollection.horizontalSizeClass != view.traitCollection.horizontalSizeClass
        || previousTraitCollection.verticalSizeClass != view.traitCollection.verticalSizeClass
      {
        view.rebuild()
      }
    }

    rebuild()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    stopDeleteRepeat()
  }

  func updateInputContext(
    kind: KeyboardInputKind,
    returnKeyType: UIReturnKeyType,
    needsInputModeSwitchKey: Bool
  ) {
    guard inputKind != kind
      || self.returnKeyType != returnKeyType
      || self.needsInputModeSwitchKey != needsInputModeSwitchKey
    else { return }
    inputKind = kind
    self.returnKeyType = returnKeyType
    self.needsInputModeSwitchKey = needsInputModeSwitchKey
    rebuild()
  }

  func applyAutomaticCapitalization(_ capitalization: KeyboardCapitalization) {
    let previous = interactionState.capitalization
    interactionState.applyAutomaticCapitalization(capitalization)
    if interactionState.capitalization != previous {
      updateOrRebuild()
    }
  }

  func resetTransientState() {
    stopDeleteRepeat()
    inputCallout.hide()
    alternateCallout.hide()
    activeLongPressOptions = []
  }

  func activate(_ action: KeyboardKeyAction) {
    switch action {
    case .text(let text):
      insertText(text)
    case .shift:
      delegate?.keyboardSurfacePlayInputClick(self)
      interactionState.tapShift(at: ProcessInfo.processInfo.systemUptime)
      updateOrRebuild()
    case .page:
      delegate?.keyboardSurfacePlayInputClick(self)
      interactionState.tapPage()
      rebuild()
    case .returnKey:
      insertText("\n", consumesShift: false)
    case .backspace:
      deleteOnce()
    case .space:
      insertText(" ", consumesShift: false)
    case .nextKeyboard:
      break
    }
  }

  private func updateOrRebuild() {
    let rows = interactionState.layout(
      inputKind: inputKind,
      needsInputModeSwitchKey: needsInputModeSwitchKey
    )
    if canUpdateInPlace(with: rows) {
      updateKeyPresentations(with: rows)
    } else {
      rebuild()
    }
  }

  private func canUpdateInPlace(with rows: [KeyboardLayoutRow]) -> Bool {
    guard !rowButtons.isEmpty, rowButtons.count == rows.count else { return false }
    for (buttons, row) in zip(rowButtons, rows) {
      if buttons.count != row.keys.count { return false }
    }
    return true
  }

  private func updateKeyPresentations(with rows: [KeyboardLayoutRow]) {
    resetTransientState()
    for (buttons, row) in zip(rowButtons, rows) {
      for (button, key) in zip(buttons, row.keys) {
        button.updateKey(key)
        let presentation = presentation(for: key.action)
        button.configure(
          title: presentation.title,
          systemImage: presentation.systemImage,
          accessibilityLabel: presentation.accessibilityLabel
        )
        button.accessibilityIdentifier = presentation.accessibilityIdentifier
        if case .text(let text) = key.action {
          let options = interactionState.alternateCharacters(for: text)
          if options.count > 1 {
            longPressOptions[ObjectIdentifier(button)] = options
          } else {
            longPressOptions.removeValue(forKey: ObjectIdentifier(button))
          }
        }
      }
    }
  }

  private func rebuild() {
    resetTransientState()
    longPressOptions.removeAll()
    rowButtons.removeAll()
    rootStack.arrangedSubviews.forEach {
      rootStack.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }

    let isRegular = traitCollection.horizontalSizeClass == .regular
    let isCompactVertical = traitCollection.verticalSizeClass == .compact
    let horizontalSpacing: CGFloat = isRegular ? 8 : 6
    let verticalSpacing: CGFloat = isCompactVertical ? 6 : (isRegular ? 12 : 11)

    rootStack.spacing = verticalSpacing

    let rows = interactionState.layout(
      inputKind: inputKind,
      needsInputModeSwitchKey: needsInputModeSwitchKey
    )

    guard !rows.isEmpty else { return }

    var rowContainers: [UIView] = []
    var rowStacks: [UIStackView] = []
    var rowButtons: [[KeyboardKeyButton]] = []

    for row in rows {
      let container = UIView()
      let stack = UIStackView()
      stack.axis = .horizontal
      stack.alignment = .fill
      stack.distribution = .fill
      stack.spacing = horizontalSpacing
      stack.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(stack)

      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: container.topAnchor),
        stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])

      let buttons = row.keys.map(makeButton)
      buttons.forEach(stack.addArrangedSubview)

      container.translatesAutoresizingMaskIntoConstraints = false
      rootStack.addArrangedSubview(container)

      rowContainers.append(container)
      rowStacks.append(stack)
      rowButtons.append(buttons)
    }

    self.rowButtons = rowButtons

    guard let firstRowButtons = rowButtons.first, let baseKey = firstRowButtons.first else {
      return
    }

    // Row 0: Full width, all keys equal to baseKey
    let firstStack = rowStacks[0]
    let firstContainer = rowContainers[0]
    NSLayoutConstraint.activate([
      firstStack.leadingAnchor.constraint(equalTo: firstContainer.leadingAnchor),
      firstStack.trailingAnchor.constraint(equalTo: firstContainer.trailingAnchor),
    ])
    for button in firstRowButtons.dropFirst() {
      button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
    }

    if rows.count >= 3 {
      // Row 1:
      let secondRowButtons = rowButtons[1]
      let secondStack = rowStacks[1]
      let secondContainer = rowContainers[1]
      let secondRowLayout = rows[1]

      for button in secondRowButtons {
        button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
      }

      if secondRowLayout.leadingInset > 0 {
        NSLayoutConstraint.activate([
          secondStack.centerXAnchor.constraint(equalTo: secondContainer.centerXAnchor),
          secondStack.leadingAnchor.constraint(greaterThanOrEqualTo: secondContainer.leadingAnchor),
          secondStack.trailingAnchor.constraint(lessThanOrEqualTo: secondContainer.trailingAnchor),
        ])
      } else {
        NSLayoutConstraint.activate([
          secondStack.leadingAnchor.constraint(equalTo: secondContainer.leadingAnchor),
          secondStack.trailingAnchor.constraint(equalTo: secondContainer.trailingAnchor),
        ])
      }

      // Row 2: Shift, letter keys, Backspace
      let thirdRowButtons = rowButtons[2]
      let thirdStack = rowStacks[2]
      let thirdContainer = rowContainers[2]

      NSLayoutConstraint.activate([
        thirdStack.leadingAnchor.constraint(equalTo: thirdContainer.leadingAnchor),
        thirdStack.trailingAnchor.constraint(equalTo: thirdContainer.trailingAnchor),
      ])

      let shiftButton = thirdRowButtons.first
      let backspaceButton = thirdRowButtons.last

      if let shift = shiftButton, let backspace = backspaceButton, thirdRowButtons.count >= 3 {
        let middleKeys = thirdRowButtons.dropFirst().dropLast()
        for button in middleKeys {
          button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
        }
        shift.widthAnchor.constraint(equalTo: backspace.widthAnchor).isActive = true
      } else {
        for button in thirdRowButtons {
          button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
        }
      }

      // Row 3 (Bottom row):
      if rows.count >= 4 {
        let bottomButtons = rowButtons[3]
        let bottomStack = rowStacks[3]
        let bottomContainer = rowContainers[3]
        let bottomRowLayout = rows[3]

        NSLayoutConstraint.activate([
          bottomStack.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor),
          bottomStack.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
        ])

        for (button, key) in zip(bottomButtons, bottomRowLayout.keys) {
          switch key.action {
          case .page:
            if needsInputModeSwitchKey {
              button.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.25).isActive = true
            } else if let shift = shiftButton {
              button.widthAnchor.constraint(equalTo: shift.widthAnchor).isActive = true
            } else {
              button.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.45).isActive = true
            }
          case .nextKeyboard:
            button.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.15).isActive = true
          case .returnKey:
            if let backspace = backspaceButton {
              button.widthAnchor.constraint(equalTo: backspace.widthAnchor).isActive = true
            } else {
              button.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.5).isActive = true
            }
          case .space:
            button.setContentHuggingPriority(UILayoutPriority(100), for: .horizontal)
            button.setContentCompressionResistancePriority(UILayoutPriority(100), for: .horizontal)
          case .text(let str):
            if str == ".com" {
              button.setContentHuggingPriority(UILayoutPriority(100), for: .horizontal)
              button.setContentCompressionResistancePriority(UILayoutPriority(100), for: .horizontal)
            } else if str.count == 1 {
              button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
            } else {
              button.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.5).isActive = true
            }
          default:
            button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
          }
        }
      }
    }
  }

  private func makeButton(for key: KeyboardLayoutKey) -> KeyboardKeyButton {
    let button = KeyboardKeyButton(key: key)
    let presentation = presentation(for: key.action)
    button.configure(
      title: presentation.title,
      systemImage: presentation.systemImage,
      accessibilityLabel: presentation.accessibilityLabel
    )
    button.accessibilityIdentifier = presentation.accessibilityIdentifier

    switch key.action {
    case .backspace:
      button.addTarget(self, action: #selector(deleteTouchDown), for: .touchDown)
      button.addTarget(
        self,
        action: #selector(deleteTouchEnded),
        for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
      )
    case .space:
      button.addTarget(self, action: #selector(spaceTouchDown), for: .touchDown)
      button.addTarget(self, action: #selector(spaceTouchUpInside), for: .touchUpInside)
      button.addTarget(
        self,
        action: #selector(spaceTouchCancelled),
        for: [.touchUpOutside, .touchCancel]
      )
      let pan = UIPanGestureRecognizer(target: self, action: #selector(spacePanned(_:)))
      pan.cancelsTouchesInView = false
      pan.delegate = self
      button.addGestureRecognizer(pan)
    case .nextKeyboard:
      button.addTarget(
        self,
        action: #selector(nextKeyboardEvent(_:event:)),
        for: .allTouchEvents
      )
    default:
      button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
      button.addTarget(self, action: #selector(keyTouchUp(_:)), for: .touchUpInside)
      button.addTarget(
        self,
        action: #selector(keyTouchCancelled),
        for: [.touchUpOutside, .touchCancel, .touchDragExit]
      )
      if case .text(let text) = key.action {
        let options = interactionState.alternateCharacters(for: text)
        if options.count > 1 {
          longPressOptions[ObjectIdentifier(button)] = options
          let recognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(keyLongPressed(_:))
          )
          recognizer.minimumPressDuration = 0.36
          button.addGestureRecognizer(recognizer)
        }
      }
    }
    return button
  }

  @objc private func keyTouchDown(_ sender: KeyboardKeyButton) {
    guard case .text(let text) = sender.key.action else { return }
    inputCallout.show(text: text, above: sender, in: self)
  }

  @objc private func keyTouchUp(_ sender: KeyboardKeyButton) {
    inputCallout.hide()
    activate(sender.key.action)
  }

  @objc private func keyTouchCancelled() {
    inputCallout.hide()
  }

  @objc private func keyLongPressed(_ recognizer: UILongPressGestureRecognizer) {
    guard let button = recognizer.view as? KeyboardKeyButton,
      let options = longPressOptions[ObjectIdentifier(button)]
    else { return }

    let point = recognizer.location(in: self)
    switch recognizer.state {
    case .began:
      inputCallout.hide()
      let buttonFrame = button.convert(button.bounds, to: self)
      let anchorsToTrailingEdge = buttonFrame.midX > bounds.midX
      activeLongPressOptions = anchorsToTrailingEdge ? Array(options.reversed()) : options
      alternateCallout.show(
        options: activeLongPressOptions,
        above: button,
        in: self,
        anchoredToTrailingEdge: anchorsToTrailingEdge
      )
      selectionFeedbackGenerator.selectionChanged()
    case .changed:
      alternateCallout.updateSelection(at: point, options: activeLongPressOptions)
    case .ended:
      if let selected = alternateCallout.selectedText {
        insertText(selected)
      }
      alternateCallout.hide()
      activeLongPressOptions = []
    case .cancelled, .failed:
      alternateCallout.hide()
      activeLongPressOptions = []
    default:
      break
    }
  }

  @objc private func deleteTouchDown() {
    activate(.backspace)
    stopDeleteRepeat()
    isDeleting = true
    let delay = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
      guard let self, self.isDeleting else { return }
      let repeating = Timer(timeInterval: 0.072, repeats: true) { [weak self] _ in
        guard let self, self.isDeleting else { return }
        self.deleteOnce()
      }
      self.deleteRepeatTimer = repeating
      RunLoop.main.add(repeating, forMode: .common)
    }
    deleteDelayTimer = delay
    RunLoop.main.add(delay, forMode: .common)
  }

  @objc private func deleteTouchEnded() {
    stopDeleteRepeat()
  }

  private func deleteOnce() {
    delegate?.keyboardSurfaceDeleteBackward(self)
    delegate?.keyboardSurfacePlayInputClick(self)
  }

  private func stopDeleteRepeat() {
    isDeleting = false
    deleteDelayTimer?.invalidate()
    deleteDelayTimer = nil
    deleteRepeatTimer?.invalidate()
    deleteRepeatTimer = nil
  }

  @objc private func spaceTouchDown() {
    spaceDidMove = false
    lastSpaceStep = 0
    selectionFeedbackGenerator.prepare()
  }

  @objc private func spaceTouchUpInside() {
    if !spaceDidMove {
      activate(.space)
    }
    lastSpaceStep = 0
  }

  @objc private func spaceTouchCancelled() {
    spaceDidMove = false
    lastSpaceStep = 0
  }

  @objc private func spacePanned(_ recognizer: UIPanGestureRecognizer) {
    let translation = recognizer.translation(in: recognizer.view)
    guard translation.x.isFinite else { return }
    if abs(translation.x) > 8 {
      spaceDidMove = true
    }
    let step = Int(translation.x / 12)
    let delta = step - lastSpaceStep
    if delta != 0 {
      delegate?.keyboardSurface(self, adjustTextPositionBy: delta)
      selectionFeedbackGenerator.selectionChanged()
      selectionFeedbackGenerator.prepare()
      lastSpaceStep = step
    }
    if recognizer.state == .ended || recognizer.state == .cancelled {
      lastSpaceStep = 0
    }
  }

  @objc private func nextKeyboardEvent(_ sender: UIButton, event: UIEvent) {
    delegate?.keyboardSurface(self, showInputModeListFrom: sender, event: event)
  }

  private func insertText(_ text: String, consumesShift: Bool = true) {
    delegate?.keyboardSurfacePlayInputClick(self)
    delegate?.keyboardSurface(self, insertText: text)
    guard consumesShift else { return }
    let previous = interactionState.capitalization
    interactionState.consumeText()
    if previous != interactionState.capitalization {
      updateOrRebuild()
    }
  }

  private func presentation(
    for action: KeyboardKeyAction
  ) -> (title: String?, systemImage: String?, accessibilityLabel: String, accessibilityIdentifier: String) {
    switch action {
    case .text(let text):
      return (text, nil, text, "keyboard-key-\(text)")
    case .shift:
      let image = interactionState.isCapsLocked
        ? "capslock.fill"
        : (interactionState.usesUppercaseLetters ? "shift.fill" : "shift")
      let value: String
      switch interactionState.page {
      case .letters: value = interactionState.isCapsLocked ? "Caps Lock" : "Shift"
      case .numbers: value = "More symbols"
      case .symbols: value = "Numbers"
      }
      return (
        interactionState.page == .letters ? nil : shiftPageTitle,
        interactionState.page == .letters ? image : nil,
        value,
        "keyboard-shift-key"
      )
    case .backspace:
      return (nil, "delete.left", "Delete", "keyboard-delete-key")
    case .page:
      return (interactionState.page == .letters ? "123" : "ABC", nil, "Change keyboard page", "keyboard-page-key")
    case .nextKeyboard:
      return (nil, "globe", "Next keyboard", "keyboard-next-keyboard-key")
    case .space:
      return ("space", nil, "Space", "keyboard-space-key")
    case .returnKey:
      let title = returnKeyTitle
      return (title, title == nil ? "return" : nil, title ?? "Return", "keyboard-return-key")
    }
  }

  private var shiftPageTitle: String {
    interactionState.page == .numbers ? "#+=" : "123"
  }

  private var returnKeyTitle: String? {
    switch returnKeyType {
    case .go: "go"
    case .google: "Google"
    case .join: "join"
    case .next: "next"
    case .route: "route"
    case .search: "search"
    case .send: "send"
    case .yahoo: "Yahoo"
    case .done: "done"
    case .continue: "continue"
    case .emergencyCall: "Emergency"
    default: nil
    }
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    true
  }
}
