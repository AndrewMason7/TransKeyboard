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
  private var deleteGeneration: UInt64 = 0
  private var longPressOptions: [ObjectIdentifier: [String]] = [:]
  private var activeLongPressOptions: [String] = []
  private var spaceDidMove = false
  private var lastSpaceStep = 0

  private var rootStackFillWidth: NSLayoutConstraint?
  private var rootStackLeading: NSLayoutConstraint?
  private var rootStackTrailing: NSLayoutConstraint?
  private var rootStackTop: NSLayoutConstraint?
  private var rootStackBottom: NSLayoutConstraint?
  private var baseKeyHeightConstraint: NSLayoutConstraint?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    clipsToBounds = false
    isMultipleTouchEnabled = true
    tintColor = UIColor { traits in
      traits.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
    }
    rootStack.axis = .vertical
    rootStack.alignment = .fill
    rootStack.distribution = .fillEqually
    rootStack.spacing = 8
    rootStack.isMultipleTouchEnabled = true
    rootStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(rootStack)

    let fillWidth = rootStack.widthAnchor.constraint(equalTo: widthAnchor, constant: -6)
    fillWidth.priority = UILayoutPriority(999)
    let leading = rootStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 3)
    let trailing = rootStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -3)
    let top = rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 6)
    let bottom = rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
    let centerX = rootStack.centerXAnchor.constraint(equalTo: centerXAnchor)
    let maxWidth = rootStack.widthAnchor.constraint(lessThanOrEqualToConstant: 760)

    NSLayoutConstraint.activate([
      leading, trailing, centerX, maxWidth, fillWidth, top, bottom,
    ])

    rootStackFillWidth = fillWidth
    rootStackLeading = leading
    rootStackTrailing = trailing
    rootStackTop = top
    rootStackBottom = bottom

    registerForTraitChanges(
      [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self, UITraitUserInterfaceStyle.self]
    ) { (view: KeyboardSurfaceView, previousTraitCollection: UITraitCollection) in
      if previousTraitCollection.horizontalSizeClass != view.traitCollection.horizontalSizeClass
        || previousTraitCollection.verticalSizeClass != view.traitCollection.verticalSizeClass
      {
        view.updateStackMetrics()
        view.rebuild()
      } else if previousTraitCollection.userInterfaceStyle != view.traitCollection.userInterfaceStyle {
        for row in view.rowButtons {
          for button in row {
            button.updateAppearance(animated: false)
          }
        }
      }
    }

    updateStackMetrics()
    rebuild()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      for row in rowButtons {
        for button in row {
          button.updateAppearance(animated: false)
        }
      }
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateStackMetrics()
  }

  private func updateStackMetrics() {
    let isRegular = traitCollection.horizontalSizeClass == .regular
    let isCompactVertical = traitCollection.verticalSizeClass == .compact
    let effectiveWidth = bounds.width > 0 ? bounds.width : (window?.bounds.width ?? 390)
    let isLargePhone = effectiveWidth > 400

    let sideMargin: CGFloat = isRegular ? 8 : (isLargePhone ? 4 : 3)
    let topPadding: CGFloat = isCompactVertical ? 2 : 3
    let bottomPadding: CGFloat = isCompactVertical ? 2 : 2
    let verticalSpacing: CGFloat = isCompactVertical ? 5 : (isRegular ? 9 : (isLargePhone ? 8.5 : 8))

    if rootStack.spacing != verticalSpacing {
      rootStack.spacing = verticalSpacing
    }
    let fillConstant = -sideMargin * 2
    if let c = rootStackFillWidth, c.constant != fillConstant {
      c.constant = fillConstant
    }
    if let c = rootStackLeading, c.constant != sideMargin {
      c.constant = sideMargin
    }
    if let c = rootStackTrailing, c.constant != -sideMargin {
      c.constant = -sideMargin
    }
    if let c = rootStackTop, c.constant != topPadding {
      c.constant = topPadding
    }
    if let c = rootStackBottom, c.constant != -bottomPadding {
      c.constant = -bottomPadding
    }

    let keyHeight: CGFloat = isRegular ? 54 : (isCompactVertical ? 36 : (isLargePhone ? 44 : 42))
    if let c = baseKeyHeightConstraint, c.constant != keyHeight {
      c.constant = keyHeight
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      resetTransientState()
    }
  }

  deinit {
    // Timers are invalidated in stopDeleteRepeat() and willMove(toWindow: nil).
    // Block-based timers use [weak self] so they do not retain this view.
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
    case .emoji:
      break
    case .nextKeyboard:
      break
    }
  }

  private func updateOrRebuild() {
    let rows = interactionState.layout(
      inputKind: inputKind,
      needsInputModeSwitchKey: needsInputModeSwitchKey
    )
    UIView.performWithoutAnimation {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      if canUpdateInPlace(with: rows) {
        updateKeyPresentations(with: rows)
      } else {
        rebuild()
      }
      self.layoutIfNeeded()
      CATransaction.commit()
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
    UIView.performWithoutAnimation {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      for (buttons, row) in zip(rowButtons, rows) {
        for (button, key) in zip(buttons, row.keys) {
          let wasSelected = button.isSelected
          let isShift = (key.action == .shift && self.interactionState.page == .letters)
          let shouldBeSelected = isShift && self.interactionState.usesUppercaseLetters

          let keyChanged = button.key != key
          let selectionChanged = wasSelected != shouldBeSelected
          let presentation = self.presentation(for: key.action)
          let titleMismatched = button.configuration?.title != presentation.title
          let isReturn = key.action == .returnKey

          button.updateKey(key)
          button.isSelected = shouldBeSelected

          if keyChanged || selectionChanged || titleMismatched || isReturn {
            button.configure(
              title: presentation.title,
              systemImage: presentation.systemImage,
              accessibilityLabel: presentation.accessibilityLabel
            )
            button.accessibilityIdentifier = presentation.accessibilityIdentifier
          }
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
      self.layoutIfNeeded()
      CATransaction.commit()
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
    let effectiveWidth = bounds.width > 0 ? bounds.width : (window?.bounds.width ?? 390)
    let isLargePhone = effectiveWidth > 400

    let horizontalSpacing: CGFloat = isRegular ? 8 : (isCompactVertical ? 5 : 6)
    let keyHeight: CGFloat = isRegular ? 56 : (isCompactVertical ? 38 : (isLargePhone ? 45 : 42))

    updateStackMetrics()

    let rows = interactionState.layout(
      inputKind: inputKind,
      needsInputModeSwitchKey: needsInputModeSwitchKey
    )

    guard !rows.isEmpty else { return }

    var rowContainers: [UIView] = []
    var rowButtons: [[KeyboardKeyButton]] = []

    for row in rows {
      let container: UIView
      if #available(iOS 26.0, *) {
        let containerEffect = UIGlassContainerEffect()
        containerEffect.spacing = horizontalSpacing
        let effectView = UIVisualEffectView(effect: containerEffect)
        effectView.isMultipleTouchEnabled = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(effectView)
        container = effectView.contentView
      } else {
        let plainView = UIView()
        plainView.isMultipleTouchEnabled = true
        plainView.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(plainView)
        container = plainView
      }
      let buttons = row.keys.map(makeButton)
      rowContainers.append(container)
      rowButtons.append(buttons)
    }

    self.rowButtons = rowButtons

    guard let firstRowButtons = rowButtons.first, let baseKey = firstRowButtons.first else {
      return
    }

    // Row 0: Full width, all keys equal to baseKey
    let firstContainer = rowContainers[0]
    let firstStack = UIStackView()
    firstStack.isMultipleTouchEnabled = true
    firstStack.axis = .horizontal
    firstStack.alignment = .fill
    firstStack.distribution = .fill
    firstStack.spacing = horizontalSpacing
    firstStack.translatesAutoresizingMaskIntoConstraints = false
    firstContainer.addSubview(firstStack)

    NSLayoutConstraint.activate([
      firstStack.topAnchor.constraint(equalTo: firstContainer.topAnchor),
      firstStack.bottomAnchor.constraint(equalTo: firstContainer.bottomAnchor),
      firstStack.leadingAnchor.constraint(equalTo: firstContainer.leadingAnchor),
      firstStack.trailingAnchor.constraint(equalTo: firstContainer.trailingAnchor),
    ])

    firstRowButtons.forEach(firstStack.addArrangedSubview)

    let baseHeightConstraint = baseKey.heightAnchor.constraint(equalToConstant: keyHeight)
    baseHeightConstraint.priority = UILayoutPriority(950)
    baseHeightConstraint.isActive = true
    baseKeyHeightConstraint = baseHeightConstraint

    for button in firstRowButtons.dropFirst() {
      button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
    }

    if rows.count >= 2 {
      // Row 1:
      let secondRowButtons = rowButtons[1]
      let secondContainer = rowContainers[1]
      let secondRowLayout = rows[1]

      let secondStack = UIStackView()
      secondStack.isMultipleTouchEnabled = true
      secondStack.axis = .horizontal
      secondStack.alignment = .fill
      secondStack.distribution = .fill
      secondStack.spacing = horizontalSpacing
      secondStack.translatesAutoresizingMaskIntoConstraints = false
      secondContainer.addSubview(secondStack)

      NSLayoutConstraint.activate([
        secondStack.topAnchor.constraint(equalTo: secondContainer.topAnchor),
        secondStack.bottomAnchor.constraint(equalTo: secondContainer.bottomAnchor),
      ])

      secondRowButtons.forEach(secondStack.addArrangedSubview)

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

      if rows.count >= 3 {
        // Row 2: Shift, letter keys, Backspace
        let thirdRowButtons = rowButtons[2]
        let thirdContainer = rowContainers[2]

        if thirdRowButtons.count >= 3,
           let shiftButton = thirdRowButtons.first,
           let backspaceButton = thirdRowButtons.last {
          let middleKeys = Array(thirdRowButtons.dropFirst().dropLast())

          shiftButton.translatesAutoresizingMaskIntoConstraints = false
          backspaceButton.translatesAutoresizingMaskIntoConstraints = false
          thirdContainer.addSubview(shiftButton)
          thirdContainer.addSubview(backspaceButton)

          let middleStack = UIStackView()
          middleStack.isMultipleTouchEnabled = true
          middleStack.axis = .horizontal
          middleStack.alignment = .fill
          middleStack.distribution = .fill
          middleStack.spacing = horizontalSpacing
          middleStack.translatesAutoresizingMaskIntoConstraints = false
          middleKeys.forEach(middleStack.addArrangedSubview)
          thirdContainer.addSubview(middleStack)

          for button in middleKeys {
            button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
          }

          NSLayoutConstraint.activate([
            middleStack.topAnchor.constraint(equalTo: thirdContainer.topAnchor),
            middleStack.bottomAnchor.constraint(equalTo: thirdContainer.bottomAnchor),
            middleStack.centerXAnchor.constraint(equalTo: thirdContainer.centerXAnchor),
            middleStack.leadingAnchor.constraint(greaterThanOrEqualTo: shiftButton.trailingAnchor, constant: horizontalSpacing),

            shiftButton.leadingAnchor.constraint(equalTo: thirdContainer.leadingAnchor),
            shiftButton.topAnchor.constraint(equalTo: thirdContainer.topAnchor),
            shiftButton.bottomAnchor.constraint(equalTo: thirdContainer.bottomAnchor),

            backspaceButton.trailingAnchor.constraint(equalTo: thirdContainer.trailingAnchor),
            backspaceButton.topAnchor.constraint(equalTo: thirdContainer.topAnchor),
            backspaceButton.bottomAnchor.constraint(equalTo: thirdContainer.bottomAnchor),
            backspaceButton.leadingAnchor.constraint(greaterThanOrEqualTo: middleStack.trailingAnchor, constant: horizontalSpacing),
            backspaceButton.widthAnchor.constraint(equalTo: shiftButton.widthAnchor),
          ])

          let shiftWidth = shiftButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.36)
          shiftWidth.priority = UILayoutPriority(950)
          shiftWidth.isActive = true
        } else {
          let thirdStack = UIStackView()
          thirdStack.isMultipleTouchEnabled = true
          thirdStack.axis = .horizontal
          thirdStack.alignment = .fill
          thirdStack.distribution = .fill
          thirdStack.spacing = horizontalSpacing
          thirdStack.translatesAutoresizingMaskIntoConstraints = false
          thirdContainer.addSubview(thirdStack)
          thirdRowButtons.forEach(thirdStack.addArrangedSubview)
          NSLayoutConstraint.activate([
            thirdStack.topAnchor.constraint(equalTo: thirdContainer.topAnchor),
            thirdStack.bottomAnchor.constraint(equalTo: thirdContainer.bottomAnchor),
            thirdStack.leadingAnchor.constraint(equalTo: thirdContainer.leadingAnchor),
            thirdStack.trailingAnchor.constraint(equalTo: thirdContainer.trailingAnchor),
          ])
          for button in thirdRowButtons {
            button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
          }
        }

        // Row 3 (Bottom row):
        if rows.count >= 4 {
          let bottomButtons = rowButtons[3]
          let bottomContainer = rowContainers[3]
          layoutBottomRow(
            buttons: bottomButtons,
            container: bottomContainer,
            baseKey: baseKey,
            secondRowButtons: secondRowButtons,
            horizontalSpacing: horizontalSpacing
          )
        }
      }
    }
    setNeedsLayout()
  }

  private func layoutBottomRow(
    buttons: [KeyboardKeyButton],
    container: UIView,
    baseKey: KeyboardKeyButton,
    secondRowButtons: [KeyboardKeyButton],
    horizontalSpacing: CGFloat
  ) {
    guard buttons.count >= 3,
          let returnButton = buttons.last
    else {
      let stack = UIStackView()
      stack.axis = .horizontal
      stack.alignment = .fill
      stack.distribution = .fillEqually
      stack.spacing = horizontalSpacing
      stack.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(stack)
      buttons.forEach(stack.addArrangedSubview)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: container.topAnchor),
        stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      ])
      return
    }

    buttons.forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview($0)
      NSLayoutConstraint.activate([
        $0.topAnchor.constraint(equalTo: container.topAnchor),
        $0.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
    }

    returnButton.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true

    if inputKind == .email {
      layoutEmailBottomRow(
        buttons: buttons,
        container: container,
        baseKey: baseKey,
        secondRowButtons: secondRowButtons,
        horizontalSpacing: horizontalSpacing
      )
    } else if inputKind == .url {
      layoutUrlBottomRow(
        buttons: buttons,
        container: container,
        baseKey: baseKey,
        secondRowButtons: secondRowButtons,
        horizontalSpacing: horizontalSpacing
      )
    } else {
      layoutStandardBottomRow(
        buttons: buttons,
        container: container,
        baseKey: baseKey,
        secondRowButtons: secondRowButtons,
        horizontalSpacing: horizontalSpacing
      )
    }
  }

  private func layoutStandardBottomRow(
    buttons: [KeyboardKeyButton],
    container: UIView,
    baseKey: KeyboardKeyButton,
    secondRowButtons: [KeyboardKeyButton],
    horizontalSpacing: CGFloat
  ) {
    guard let returnButton = buttons.last,
          let pageButton = buttons.first
    else { return }

    pageButton.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true

    let hasNineKeySecondRow = secondRowButtons.count == 9

    if buttons.count == 4 {
      // [123/ABC, space, dot, return]
      guard let spaceButton = buttons[safe: 1],
            let dotButton = buttons[safe: 2]
      else { return }

      if hasNineKeySecondRow,
         let secondRow1 = secondRowButtons[safe: 1],
         let secondRow2 = secondRowButtons[safe: 2],
         let secondRow5 = secondRowButtons[safe: 5],
         let secondRow6 = secondRowButtons[safe: 6],
         let secondRow7 = secondRowButtons[safe: 7] {
        NSLayoutConstraint.activate([
          pageButton.trailingAnchor.constraint(equalTo: secondRow1.trailingAnchor),
          spaceButton.leadingAnchor.constraint(equalTo: secondRow2.leadingAnchor),
          spaceButton.trailingAnchor.constraint(equalTo: secondRow5.trailingAnchor),
          dotButton.leadingAnchor.constraint(equalTo: secondRow6.leadingAnchor),
          dotButton.trailingAnchor.constraint(equalTo: secondRow6.trailingAnchor),
          returnButton.leadingAnchor.constraint(equalTo: secondRow7.leadingAnchor),
        ])
      } else {
        NSLayoutConstraint.activate([
          returnButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 2.5, constant: 1.5 * horizontalSpacing),
          pageButton.widthAnchor.constraint(equalTo: returnButton.widthAnchor),
          dotButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor),
          dotButton.trailingAnchor.constraint(equalTo: returnButton.leadingAnchor, constant: -horizontalSpacing),
          spaceButton.leadingAnchor.constraint(equalTo: pageButton.trailingAnchor, constant: horizontalSpacing),
          spaceButton.trailingAnchor.constraint(equalTo: dotButton.leadingAnchor, constant: -horizontalSpacing),
        ])
      }
    } else if buttons.count == 5 {
      // [123/ABC, globe, space, dot, return]
      guard let globeButton = buttons[safe: 1],
            let spaceButton = buttons[safe: 2],
            let dotButton = buttons[safe: 3]
      else { return }

      NSLayoutConstraint.activate([
        globeButton.leadingAnchor.constraint(equalTo: pageButton.trailingAnchor, constant: horizontalSpacing),
        globeButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor),
      ])

      if hasNineKeySecondRow,
         let secondRow1 = secondRowButtons[safe: 1],
         let secondRow2 = secondRowButtons[safe: 2],
         let secondRow5 = secondRowButtons[safe: 5],
         let secondRow6 = secondRowButtons[safe: 6],
         let secondRow7 = secondRowButtons[safe: 7] {
        NSLayoutConstraint.activate([
          globeButton.trailingAnchor.constraint(equalTo: secondRow1.trailingAnchor),
          spaceButton.leadingAnchor.constraint(equalTo: secondRow2.leadingAnchor),
          spaceButton.trailingAnchor.constraint(equalTo: secondRow5.trailingAnchor),
          dotButton.leadingAnchor.constraint(equalTo: secondRow6.leadingAnchor),
          dotButton.trailingAnchor.constraint(equalTo: secondRow6.trailingAnchor),
          returnButton.leadingAnchor.constraint(equalTo: secondRow7.leadingAnchor),
        ])
      } else {
        NSLayoutConstraint.activate([
          returnButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 2.5, constant: 1.5 * horizontalSpacing),
          pageButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.5, constant: 0.5 * horizontalSpacing),
          dotButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor),
          dotButton.trailingAnchor.constraint(equalTo: returnButton.leadingAnchor, constant: -horizontalSpacing),
          spaceButton.leadingAnchor.constraint(equalTo: globeButton.trailingAnchor, constant: horizontalSpacing),
          spaceButton.trailingAnchor.constraint(equalTo: dotButton.leadingAnchor, constant: -horizontalSpacing),
        ])
      }
    } else {
      // General fallback
      let pageWidthConstraint = pageButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.5)
      pageWidthConstraint.priority = UILayoutPriority(900)
      pageWidthConstraint.isActive = true

      var previous = pageButton
      for button in buttons.dropFirst().dropLast() {
        button.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: horizontalSpacing).isActive = true
        if case .space = button.key.action {
          // space fills
        } else if case .text(".") = button.key.action {
          button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
        } else {
          button.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.15).isActive = true
        }
        previous = button
      }
      returnButton.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: horizontalSpacing).isActive = true
      returnButton.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.25).isActive = true
    }
  }

  private func layoutEmailBottomRow(
    buttons: [KeyboardKeyButton],
    container: UIView,
    baseKey: KeyboardKeyButton,
    secondRowButtons: [KeyboardKeyButton],
    horizontalSpacing: CGFloat
  ) {
    guard let pageButton = buttons.first,
          let returnButton = buttons.last
    else { return }

    pageButton.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
    let pageWidth = pageButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.36)
    pageWidth.priority = UILayoutPriority(950)
    pageWidth.isActive = true

    let returnWidth = returnButton.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.25)
    returnWidth.priority = UILayoutPriority(950)
    returnWidth.isActive = true

    var spaceIndex = -1
    for (index, button) in buttons.enumerated() {
      if case .space = button.key.action {
        spaceIndex = index
        break
      }
    }

    if spaceIndex > 0 {
      guard let spaceButton = buttons[safe: spaceIndex] else { return }
      for i in 1..<spaceIndex {
        guard let btn = buttons[safe: i], let prevBtn = buttons[safe: i - 1] else { continue }
        btn.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
        btn.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor, constant: horizontalSpacing).isActive = true
      }
      if let prevBtn = buttons[safe: spaceIndex - 1] {
        spaceButton.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor, constant: horizontalSpacing).isActive = true
      }

      var nextAfterSpace = spaceButton
      for i in (spaceIndex + 1)..<(buttons.count - 1) {
        guard let btn = buttons[safe: i] else { continue }
        btn.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
        btn.leadingAnchor.constraint(equalTo: nextAfterSpace.trailingAnchor, constant: horizontalSpacing).isActive = true
        nextAfterSpace = btn
      }
      returnButton.leadingAnchor.constraint(equalTo: nextAfterSpace.trailingAnchor, constant: horizontalSpacing).isActive = true
    }
  }

  private func layoutUrlBottomRow(
    buttons: [KeyboardKeyButton],
    container: UIView,
    baseKey: KeyboardKeyButton,
    secondRowButtons: [KeyboardKeyButton],
    horizontalSpacing: CGFloat
  ) {
    guard let pageButton = buttons.first,
          let returnButton = buttons.last
    else { return }

    pageButton.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
    let pageWidth = pageButton.widthAnchor.constraint(equalTo: baseKey.widthAnchor, multiplier: 1.36)
    pageWidth.priority = UILayoutPriority(950)
    pageWidth.isActive = true

    let returnWidth = returnButton.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.25)
    returnWidth.priority = UILayoutPriority(950)
    returnWidth.isActive = true

    let middleButtons = buttons.dropFirst().dropLast()
    var previous = pageButton
    for button in middleButtons {
      button.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: horizontalSpacing).isActive = true
      if case .text(let str) = button.key.action, str == ".com" {
        // .com takes remaining space
      } else {
        button.widthAnchor.constraint(equalTo: baseKey.widthAnchor).isActive = true
      }
      previous = button
    }
    returnButton.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: horizontalSpacing).isActive = true
  }

  private func makeButton(for key: KeyboardLayoutKey) -> KeyboardKeyButton {
    let button = KeyboardKeyButton(key: key)
    if case .shift = key.action, interactionState.page == .letters {
      button.isSelected = interactionState.usesUppercaseLetters
    }
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
      pan.delaysTouchesEnded = false
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
          recognizer.delaysTouchesEnded = false
          button.addGestureRecognizer(recognizer)
        }
      }
    }
    return button
  }

  @objc func keyTouchDown(_ sender: KeyboardKeyButton) {
    guard case .text(let text) = sender.key.action else { return }
    inputCallout.show(text: text, above: sender, in: self)
  }

  @objc func keyTouchUp(_ sender: KeyboardKeyButton) {
    inputCallout.hide(animated: true)
    activate(sender.key.action)
  }

  @objc func keyTouchCancelled() {
    inputCallout.hide(animated: true)
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
    deleteGeneration &+= 1
    let token = deleteGeneration
    let delay = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.isDeleting, self.deleteGeneration == token else { return }
        let repeating = Timer(timeInterval: 0.072, repeats: true) { [weak self] _ in
          MainActor.assumeIsolated {
            guard let self, self.isDeleting, self.deleteGeneration == token else { return }
            self.deleteOnce()
          }
        }
        self.deleteRepeatTimer?.invalidate()
        self.deleteRepeatTimer = repeating
        RunLoop.main.add(repeating, forMode: .common)
      }
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
    deleteGeneration &+= 1
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
      return (nil, nil, "Space", "keyboard-space-key")
    case .emoji:
      return (nil, "face.smiling", "Emoji", "keyboard-emoji-key")
    case .returnKey:
      let isCompact = traitCollection.horizontalSizeClass != .regular
      let showsArrow = isCompact && (returnKeyType == .go || returnKeyType == .next)
      let systemImage: String? = (returnKeyType == .search) ? "magnifyingglass" : (showsArrow ? "arrow.right" : (returnKeyTitle == nil ? "return" : nil))
      let title = showsArrow ? nil : returnKeyTitle
      let label: String
      switch returnKeyType {
      case .search: label = "Search"
      case .go: label = "go"
      case .next: label = "next"
      default: label = title ?? "Return"
      }
      return (title, systemImage, label, "keyboard-return-key")
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
    case .search: nil
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

extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
