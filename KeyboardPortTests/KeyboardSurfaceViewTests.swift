import UIKit
import XCTest

@MainActor
final class KeyboardSurfaceViewTests: XCTestCase {
  func testTypingConsumesSingleShiftAndUsesUppercaseText() throws {
    let (surface, delegate) = makeSurface()

    surface.activate(try button("keyboard-shift-key", in: surface).key.action)
    XCTAssertNotNil(findButton("keyboard-key-Q", in: surface))

    let q = try button("keyboard-key-Q", in: surface)
    surface.activate(q.key.action)

    XCTAssertEqual(delegate.insertedText, ["Q"])
    XCTAssertEqual(surface.interactionState.capitalization, .lowercase)
    XCTAssertNotNil(findButton("keyboard-key-q", in: surface))
  }

  func testSpaceAndDeleteDispatchExactlyOnceForATap() throws {
    let (surface, delegate) = makeSurface()

    surface.activate(try button("keyboard-space-key", in: surface).key.action)
    surface.activate(try button("keyboard-delete-key", in: surface).key.action)

    XCTAssertEqual(delegate.insertedText, [" "])
    XCTAssertEqual(delegate.deleteCount, 1)
  }

  func testPageKeysRenderNumbersThenSymbols() throws {
    let (surface, _) = makeSurface()

    surface.activate(try button("keyboard-page-key", in: surface).key.action)
    XCTAssertEqual(surface.interactionState.page, .numbers)
    XCTAssertNotNil(findButton("keyboard-key-1", in: surface))

    surface.activate(try button("keyboard-shift-key", in: surface).key.action)
    XCTAssertEqual(surface.interactionState.page, .symbols)
    XCTAssertNotNil(findButton("keyboard-key-[", in: surface))
  }

  func testContextChangesRebuildTheBottomRow() {
    let (surface, _) = makeSurface()

    surface.updateInputContext(
      kind: .email,
      returnKeyType: .send,
      needsInputModeSwitchKey: false
    )
    XCTAssertNotNil(findButton("keyboard-key-@", in: surface))
    XCTAssertNotNil(findButton("keyboard-space-key", in: surface))
    XCTAssertNil(findButton("keyboard-next-keyboard-key", in: surface))
    XCTAssertEqual(findButton("keyboard-return-key", in: surface)?.accessibilityLabel, "send")

    surface.updateInputContext(
      kind: .url,
      returnKeyType: .go,
      needsInputModeSwitchKey: true
    )
    XCTAssertNotNil(findButton("keyboard-key-.com", in: surface))
    XCTAssertNil(findButton("keyboard-space-key", in: surface))
    XCTAssertNotNil(findButton("keyboard-next-keyboard-key", in: surface))

    surface.updateInputContext(
      kind: .standard,
      returnKeyType: .default,
      needsInputModeSwitchKey: true
    )
    XCTAssertNil(findButton("keyboard-emoji-key", in: surface))
    XCTAssertNotNil(findButton("keyboard-key-.", in: surface))
  }

  func testStandardBottomRowExpandsPageKeyAndPlacesDotRightOfSpace() throws {
    let (surface, _) = makeSurface()
    surface.updateInputContext(
      kind: .standard,
      returnKeyType: .default,
      needsInputModeSwitchKey: false
    )
    surface.layoutIfNeeded()

    let page = try button("keyboard-page-key", in: surface)
    let space = try button("keyboard-space-key", in: surface)
    let dot = try button("keyboard-key-.", in: surface)
    let ret = try button("keyboard-return-key", in: surface)

    XCTAssertNil(findButton("keyboard-emoji-key", in: surface))

    let pageFrame = page.convert(page.bounds, to: surface)
    let spaceFrame = space.convert(space.bounds, to: surface)
    let dotFrame = dot.convert(dot.bounds, to: surface)
    let retFrame = ret.convert(ret.bounds, to: surface)

    // Page key (123) is expanded and precedes space
    XCTAssertGreaterThan(pageFrame.width, 50)
    XCTAssertLessThan(pageFrame.maxX, spaceFrame.minX)

    // Dot key is placed to the right of space and before return
    XCTAssertGreaterThan(dotFrame.minX, spaceFrame.maxX)
    XCTAssertLessThan(dotFrame.maxX, retFrame.minX)

    // With input mode switch key (globe)
    surface.updateInputContext(
      kind: .standard,
      returnKeyType: .default,
      needsInputModeSwitchKey: true
    )
    surface.layoutIfNeeded()
    let switchPage = try button("keyboard-page-key", in: surface)
    let globe = try button("keyboard-next-keyboard-key", in: surface)
    let switchSpace = try button("keyboard-space-key", in: surface)
    let switchDot = try button("keyboard-key-.", in: surface)

    XCTAssertNil(findButton("keyboard-emoji-key", in: surface))
    let switchPageFrame = switchPage.convert(switchPage.bounds, to: surface)
    let globeFrame = globe.convert(globe.bounds, to: surface)
    let switchDotFrame = switchDot.convert(switchDot.bounds, to: surface)
    let switchSpaceFrame = switchSpace.convert(switchSpace.bounds, to: surface)

    XCTAssertLessThan(switchPageFrame.maxX, globeFrame.minX)
    XCTAssertLessThan(globeFrame.maxX, switchSpaceFrame.minX)
    XCTAssertGreaterThan(switchDotFrame.minX, switchSpaceFrame.maxX)
  }

  func testBothBottomRows123AndABCHaveSameSize() throws {
    let (surface, _) = makeSurface()
    surface.updateInputContext(
      kind: .standard,
      returnKeyType: .default,
      needsInputModeSwitchKey: false
    )
    surface.layoutIfNeeded()

    // 1. On letters page: Page button is "123"
    let lettersPage = try button("keyboard-page-key", in: surface)
    let lettersSpace = try button("keyboard-space-key", in: surface)
    let lettersDot = try XCTUnwrap(allSubviews(of: surface).compactMap { $0 as? KeyboardKeyButton }.filter { $0.accessibilityIdentifier == "keyboard-key-." }.last)
    let lettersReturn = try button("keyboard-return-key", in: surface)

    let lettersPageFrame = lettersPage.convert(lettersPage.bounds, to: surface)
    let lettersSpaceFrame = lettersSpace.convert(lettersSpace.bounds, to: surface)
    let lettersDotFrame = lettersDot.convert(lettersDot.bounds, to: surface)
    let lettersReturnFrame = lettersReturn.convert(lettersReturn.bounds, to: surface)

    // 2. Switch to numbers page: Page button becomes "ABC"
    surface.activate(lettersPage.key.action)
    surface.layoutIfNeeded()
    XCTAssertEqual(surface.interactionState.page, .numbers)

    let numbersPage = try button("keyboard-page-key", in: surface)
    let numbersSpace = try button("keyboard-space-key", in: surface)
    let numbersDot = try XCTUnwrap(allSubviews(of: surface).compactMap { $0 as? KeyboardKeyButton }.filter { $0.accessibilityIdentifier == "keyboard-key-." }.last)
    let numbersReturn = try button("keyboard-return-key", in: surface)

    let numbersPageFrame = numbersPage.convert(numbersPage.bounds, to: surface)
    let numbersSpaceFrame = numbersSpace.convert(numbersSpace.bounds, to: surface)
    let numbersDotFrame = numbersDot.convert(numbersDot.bounds, to: surface)
    let numbersReturnFrame = numbersReturn.convert(numbersReturn.bounds, to: surface)

    // Both bottom rows must be identical in width and placement (zero jitter)
    XCTAssertEqual(numbersPageFrame.width, lettersPageFrame.width, accuracy: 0.5)
    XCTAssertEqual(numbersPageFrame.minX, lettersPageFrame.minX, accuracy: 0.5)

    XCTAssertEqual(numbersSpaceFrame.width, lettersSpaceFrame.width, accuracy: 0.5)
    XCTAssertEqual(numbersSpaceFrame.minX, lettersSpaceFrame.minX, accuracy: 0.5)

    XCTAssertEqual(numbersDotFrame.width, lettersDotFrame.width, accuracy: 0.5)
    XCTAssertEqual(numbersDotFrame.minX, lettersDotFrame.minX, accuracy: 0.5)

    XCTAssertEqual(numbersReturnFrame.width, lettersReturnFrame.width, accuracy: 0.5)
    XCTAssertEqual(numbersReturnFrame.minX, lettersReturnFrame.minX, accuracy: 0.5)
  }

  func testRenderedPhoneLayoutHasNoAmbiguousSubviews() {
    let (surface, _) = makeSurface()
    surface.layoutIfNeeded()
    XCTAssertFalse(allSubviews(of: surface).contains(where: \.hasAmbiguousLayout))
  }

  func testRenderedPhoneLayoutFillsAvailableWidth() throws {
    let (surface, _) = makeSurface()
    surface.layoutIfNeeded()

    let q = try button("keyboard-key-q", in: surface)
    let p = try button("keyboard-key-p", in: surface)
    let qFrame = q.convert(q.bounds, to: surface)
    let pFrame = p.convert(p.bounds, to: surface)

    XCTAssertGreaterThan(qFrame.width, 25)
    XCTAssertLessThan(qFrame.minX, 10)
    XCTAssertGreaterThan(pFrame.maxX, 380)
  }

  func testKeySizesAreRegularAcrossRows() throws {
    let (surface, _) = makeSurface()
    surface.layoutIfNeeded()

    let q = try button("keyboard-key-q", in: surface)
    let a = try button("keyboard-key-a", in: surface)
    let s = try button("keyboard-key-s", in: surface)
    let z = try button("keyboard-key-z", in: surface)
    let shift = try button("keyboard-shift-key", in: surface)
    let backspace = try button("keyboard-delete-key", in: surface)

    // Letter keys across rows 1, 2, and 3 must have equal width
    XCTAssertEqual(q.bounds.width, a.bounds.width, accuracy: 0.5)
    XCTAssertEqual(q.bounds.width, z.bounds.width, accuracy: 0.5)

    let qFrame = q.convert(q.bounds, to: surface)
    let aFrame = a.convert(a.bounds, to: surface)
    let sFrame = s.convert(s.bounds, to: surface)
    let zFrame = z.convert(z.bounds, to: surface)
    let shiftFrame = shift.convert(shift.bounds, to: surface)
    let backspaceFrame = backspace.convert(backspace.bounds, to: surface)

    // Row 2 ('A') is indented relative to Row 1 ('Q')
    XCTAssertGreaterThan(aFrame.minX, qFrame.minX)

    // 'Z' aligns under 'S'
    XCTAssertEqual(zFrame.minX, sFrame.minX, accuracy: 1.0)

    // Shift and Backspace are symmetrically sized
    XCTAssertEqual(shiftFrame.width, backspaceFrame.width, accuracy: 1.0)

    // Single-character punctuation on an input kind with punctuation (e.g. email) has regular base key width
    surface.updateInputContext(kind: .email, returnKeyType: .default, needsInputModeSwitchKey: true)
    surface.layoutIfNeeded()
    let emailQ = try button("keyboard-key-q", in: surface)
    let dot = try button("keyboard-key-.", in: surface)
    XCTAssertEqual(emailQ.bounds.width, dot.bounds.width, accuracy: 0.5)
  }

  func testWideLayoutKeepsTypingKeysAtAUsableSize() throws {
    let surface = KeyboardSurfaceView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 260))
    surface.layoutIfNeeded()

    let q = try button("keyboard-key-q", in: surface)
    XCTAssertLessThan(q.bounds.width, 90)
    XCTAssertFalse(allSubviews(of: surface).contains(where: \.hasAmbiguousLayout))
  }

  func testTrailingAlternateCalloutStartsOnTheBaseCharacterAndStaysOnscreen() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
    let key = UIView(frame: CGRect(x: 348, y: 90, width: 38, height: 44))
    let callout = KeyboardAlternateCalloutView()
    container.addSubview(key)

    let rightAnchoredOptions = ["ō", "õ", "ø", "œ", "ö", "ô", "ó", "ò", "o"]
    callout.show(
      options: rightAnchoredOptions,
      above: key,
      in: container,
      anchoredToTrailingEdge: true
    )

    XCTAssertEqual(callout.selectedText, "o")
    XCTAssertLessThanOrEqual(callout.frame.maxX, container.bounds.maxX - 4)
  }

  func testShiftUpdatePreservesButtonIdentityWithoutReallocatingViews() throws {
    let (surface, _) = makeSurface()
    let initialQ = try button("keyboard-key-q", in: surface)

    surface.activate(.shift)

    let uppercaseQ = try button("keyboard-key-Q", in: surface)
    // The exact same button instance must be updated in-place (no allocation/teardown)
    XCTAssertTrue(initialQ === uppercaseQ)

    // Consecutive tap within doubleTapInterval enters caps lock (letters remain uppercase)
    surface.activate(.shift)
    XCTAssertTrue(surface.interactionState.isCapsLocked)
    let capsQ = try button("keyboard-key-Q", in: surface)
    XCTAssertTrue(initialQ === capsQ)

    // Tap exits caps lock back to lowercase
    surface.activate(.shift)
    let lowercaseQ = try button("keyboard-key-q", in: surface)
    XCTAssertTrue(initialQ === lowercaseQ)
  }

  func testAlternateCalloutWithAdversarialPointsDoesNotCrash() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
    let key = UIView(frame: CGRect(x: 100, y: 90, width: 38, height: 44))
    let callout = KeyboardAlternateCalloutView()
    container.addSubview(key)

    let options = ["a", "à", "á", "â", "ä"]
    callout.show(options: options, above: key, in: container, anchoredToTrailingEdge: false)

    // Normal selection
    callout.updateSelection(at: CGPoint(x: 50, y: 20), options: options)
    XCTAssertNotNil(callout.selectedText)

    // Adversarial inputs: NaN, infinity, extreme negative, extreme positive
    callout.updateSelection(at: CGPoint(x: CGFloat.nan, y: 0), options: options)
    callout.updateSelection(at: CGPoint(x: CGFloat.infinity, y: 0), options: options)
    callout.updateSelection(at: CGPoint(x: -999999, y: 0), options: options)
    callout.updateSelection(at: CGPoint(x: 999999, y: 0), options: options)

    // Empty options guard
    callout.updateSelection(at: CGPoint(x: 10, y: 10), options: [])
    XCTAssertNotNil(callout)
  }

  func testInputCalloutDoesNotCrashInNarrowContainer() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 220))
    let key = UIView(frame: CGRect(x: 5, y: 90, width: 30, height: 44))
    let callout = KeyboardInputCalloutView()
    container.addSubview(key)

    callout.show(text: "A", above: key, in: container)
    XCTAssertFalse(callout.isHidden)
    callout.hide()
    XCTAssertTrue(callout.isHidden)
  }

  func testTopRowKeyCalloutPositionsAboveKeycapWithoutObscuringIt() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
    let key = UIView(frame: CGRect(x: 60, y: 0, width: 34, height: 44))
    let callout = KeyboardInputCalloutView()
    container.addSubview(key)

    callout.show(text: "Q", above: key, in: container)
    // The callout frame must float above the top row key (minY < 0 relative to key.minY == 0),
    // and must NOT be clamped to y == 2 where it would obscure the keycap and finger.
    XCTAssertLessThan(callout.frame.minY, 0)
    XCTAssertEqual(callout.frame.midX, key.frame.midX, accuracy: 2.0)
  }

  func testTopRowNumberAndSymbolAlternates() {
    let state = KeyboardInteractionState()
    XCTAssertEqual(state.alternateCharacters(for: "0"), ["0", "°"])
    XCTAssertEqual(state.alternateCharacters(for: "%"), ["%", "‰"])
    XCTAssertEqual(state.alternateCharacters(for: "="), ["=", "≠", "≈"])
  }

  func testKeyButtonsDoNotUseExclusiveTouchAndSupportMultipleTouch() throws {
    let (surface, _) = makeSurface()
    let keyA = try button("keyboard-key-a", in: surface)
    let keyB = try button("keyboard-key-b", in: surface)
    let space = try button("keyboard-space-key", in: surface)

    XCTAssertFalse(keyA.isExclusiveTouch, "KeyboardKeyButton must not use isExclusiveTouch to allow rapid two-thumb rollover")
    XCTAssertFalse(keyB.isExclusiveTouch, "KeyboardKeyButton must not use isExclusiveTouch to allow rapid two-thumb rollover")
    XCTAssertFalse(space.isExclusiveTouch, "Space button must not use isExclusiveTouch")
    XCTAssertTrue(surface.isMultipleTouchEnabled, "KeyboardSurfaceView must have isMultipleTouchEnabled set to true")
  }

  func testKeyRolloverRapidTypingDispatchesBothCharacters() throws {
    let (surface, delegate) = makeSurface()
    let keyH = try button("keyboard-key-h", in: surface)
    let keyE = try button("keyboard-key-e", in: surface)

    // Simulate key rollover:
    // 1. Thumb 1 touches down on 'H'
    surface.keyTouchDown(keyH)
    // 2. Thumb 2 touches down on 'E' before Thumb 1 lifts (rollover)
    surface.keyTouchDown(keyE)
    // 3. Thumb 1 lifts inside 'H'
    surface.keyTouchUp(keyH)
    // 4. Thumb 2 lifts inside 'E'
    surface.keyTouchUp(keyE)

    XCTAssertEqual(delegate.insertedText, ["h", "e"])
  }

  func testTouchSlopExpandsHitTestRegionToPreventEarlyCancellation() throws {
    let (surface, _) = makeSurface()
    let keyA = try button("keyboard-key-a", in: surface)

    // Point exactly on the boundary:
    let boundaryPoint = CGPoint(x: keyA.bounds.maxX + 4, y: keyA.bounds.midY)
    XCTAssertTrue(keyA.point(inside: boundaryPoint, with: nil), "Key should include horizontal touch slop")

    let verticalSlopPoint = CGPoint(x: keyA.bounds.midX, y: keyA.bounds.maxY + 6)
    XCTAssertTrue(keyA.point(inside: verticalSlopPoint, with: nil), "Key should include vertical touch slop")
  }

  func testShiftKeyReflectsActiveSelectionState() throws {
    let (surface, _) = makeSurface()
    let shiftButton = try button("keyboard-shift-key", in: surface)
    XCTAssertFalse(shiftButton.isSelected)

    surface.activate(.shift)
    XCTAssertTrue(shiftButton.isSelected)

    surface.activate(.text("H"))
    XCTAssertFalse(shiftButton.isSelected)
  }

  func testKeycapsDisplayValidTitlesAndSystemImages() throws {
    let (surface, _) = makeSurface()

    // In lowercase state
    let qButton = try button("keyboard-key-q", in: surface)
    XCTAssertEqual(qButton.configuration?.title, "q")

    let deleteButton = try button("keyboard-delete-key", in: surface)
    XCTAssertNotNil(deleteButton.configuration?.image)
    XCTAssertNil(deleteButton.configuration?.title)

    let pageButton = try button("keyboard-page-key", in: surface)
    XCTAssertEqual(pageButton.configuration?.title, "123")

    // Switch to uppercase
    surface.activate(.shift)
    let uppercaseQButton = try button("keyboard-key-Q", in: surface)
    XCTAssertEqual(uppercaseQButton.configuration?.title, "Q")

    let shiftButton = try button("keyboard-shift-key", in: surface)
    XCTAssertTrue(shiftButton.isSelected)
    XCTAssertNotNil(shiftButton.configuration?.image)
  }

  private func makeSurface() -> (KeyboardSurfaceView, DelegateSpy) {
    let surface = KeyboardSurfaceView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
    let delegate = DelegateSpy()
    surface.delegate = delegate
    surface.updateInputContext(
      kind: .standard,
      returnKeyType: .default,
      needsInputModeSwitchKey: true
    )
    surface.layoutIfNeeded()
    return (surface, delegate)
  }

  private func button(
    _ identifier: String,
    in surface: KeyboardSurfaceView,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> KeyboardKeyButton {
    try XCTUnwrap(findButton(identifier, in: surface), file: file, line: line)
  }

  private func findButton(
    _ identifier: String,
    in surface: KeyboardSurfaceView
  ) -> KeyboardKeyButton? {
    allSubviews(of: surface)
      .compactMap { $0 as? KeyboardKeyButton }
      .first { $0.accessibilityIdentifier == identifier }
  }

  private func allSubviews(of view: UIView) -> [UIView] {
    view.subviews + view.subviews.flatMap(allSubviews)
  }
}

@MainActor
private final class DelegateSpy: KeyboardSurfaceViewDelegate {
  var insertedText: [String] = []
  var deleteCount = 0
  var cursorOffsets: [Int] = []
  var clickCount = 0

  func keyboardSurface(_ surface: KeyboardSurfaceView, insertText text: String) {
    insertedText.append(text)
  }

  func keyboardSurfaceDeleteBackward(_ surface: KeyboardSurfaceView) {
    deleteCount += 1
  }

  func keyboardSurface(_ surface: KeyboardSurfaceView, adjustTextPositionBy offset: Int) {
    cursorOffsets.append(offset)
  }

  func keyboardSurfacePlayInputClick(_ surface: KeyboardSurfaceView) {
    clickCount += 1
  }

  func keyboardSurface(
    _ surface: KeyboardSurfaceView,
    showInputModeListFrom button: UIButton,
    event: UIEvent
  ) {}
}
