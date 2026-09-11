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
    let dot = try button("keyboard-key-.", in: surface)
    let shift = try button("keyboard-shift-key", in: surface)
    let backspace = try button("keyboard-delete-key", in: surface)

    // Letter keys across rows 1, 2, and 3 must have equal width
    XCTAssertEqual(q.bounds.width, a.bounds.width, accuracy: 0.5)
    XCTAssertEqual(q.bounds.width, z.bounds.width, accuracy: 0.5)
    // Single-character punctuation on the bottom row must also have regular base key width
    XCTAssertEqual(q.bounds.width, dot.bounds.width, accuracy: 0.5)

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

    // Second tap within doubleTapInterval enters caps lock (letters remain uppercase)
    surface.activate(.shift)
    XCTAssertTrue(surface.interactionState.isCapsLocked)
    let capsQ = try button("keyboard-key-Q", in: surface)
    XCTAssertTrue(initialQ === capsQ)

    // Third tap exits caps lock back to lowercase
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
