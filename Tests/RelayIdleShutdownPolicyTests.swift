import XCTest

@testable import GeminiVoice

final class RelayIdleShutdownPolicyTests: XCTestCase {
  func testIdleRelayStopsAtTwoMinutesByDefault() {
    XCTAssertTrue(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: false,
        timeoutSeconds: 120
      )
    )
    XCTAssertEqual(RelayIdleShutdownPolicy.timeout, 120)
  }

  func testIdleRelayWithNeverTimeoutDoesNotStop() {
    XCTAssertFalse(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: false,
        timeoutSeconds: RelayIdleTimeout.never.rawSeconds
      )
    )
    XCTAssertFalse(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: false,
        timeoutSeconds: 0
      )
    )
  }

  func testIdleRelayWithCustomTimeoutStopsWhenEligible() {
    XCTAssertTrue(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: false,
        timeoutSeconds: 300
      )
    )
    XCTAssertTrue(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: false,
        timeoutSeconds: 420
      )
    )
  }

  func testBusyOperationAndPendingHandoffSuspendShutdown() {
    XCTAssertFalse(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: true,
        hasPendingHandoff: false,
        hasPendingCommand: false
      )
    )
    XCTAssertFalse(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: true,
        hasPendingCommand: false
      )
    )
    XCTAssertFalse(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: true,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: true
      )
    )
  }

  func testStoppedRelayNeverSchedulesAnotherDeadline() {
    XCTAssertFalse(
      RelayIdleShutdownPolicy.canStop(
        relayIsRunning: false,
        operationIsBusy: false,
        hasPendingHandoff: false,
        hasPendingCommand: false
      )
    )
  }

  func testRelayIdleTimeoutFormattingAndDurations() {
    XCTAssertEqual(RelayIdleTimeout.twoMinutes.rawSeconds, 120)
    XCTAssertEqual(RelayIdleTimeout.twoMinutes.formattedDuration, "2 minutes")
    XCTAssertEqual(RelayIdleTimeout.twoMinutes.timeInterval, 120)
    XCTAssertFalse(RelayIdleTimeout.twoMinutes.isNever)

    XCTAssertEqual(RelayIdleTimeout.fiveMinutes.rawSeconds, 300)
    XCTAssertEqual(RelayIdleTimeout.fiveMinutes.formattedDuration, "5 minutes")

    XCTAssertEqual(RelayIdleTimeout.tenMinutes.rawSeconds, 600)
    XCTAssertEqual(RelayIdleTimeout.tenMinutes.formattedDuration, "10 minutes")

    XCTAssertEqual(RelayIdleTimeout.oneHour.rawSeconds, 3600)
    XCTAssertEqual(RelayIdleTimeout.oneHour.formattedDuration, "1 hour")

    let customSeven = RelayIdleTimeout(rawSeconds: 420)
    XCTAssertEqual(customSeven.formattedDuration, "7 minutes")
    XCTAssertEqual(customSeven.timeInterval, 420)
    XCTAssertFalse(customSeven.isNever)

    let never = RelayIdleTimeout.never
    XCTAssertTrue(never.isNever)
    XCTAssertNil(never.timeInterval)
    XCTAssertEqual(never.formattedDuration, "never")
    XCTAssertEqual(never.title, "Never (Stay armed)")
  }
}
