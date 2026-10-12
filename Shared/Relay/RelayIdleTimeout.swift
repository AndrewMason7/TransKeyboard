import Foundation

public struct RelayIdleTimeout: Hashable, Equatable, Sendable, Identifiable, Codable {
  public let rawSeconds: Int

  public var id: Int { rawSeconds }

  public init(rawSeconds: Int) {
    self.rawSeconds = rawSeconds
  }

  public var isNever: Bool {
    rawSeconds <= 0
  }

  public var timeInterval: TimeInterval? {
    isNever ? nil : TimeInterval(rawSeconds)
  }

  public static let twoMinutes = RelayIdleTimeout(rawSeconds: 120)
  public static let fiveMinutes = RelayIdleTimeout(rawSeconds: 300)
  public static let tenMinutes = RelayIdleTimeout(rawSeconds: 600)
  public static let fifteenMinutes = RelayIdleTimeout(rawSeconds: 900)
  public static let thirtyMinutes = RelayIdleTimeout(rawSeconds: 1800)
  public static let oneHour = RelayIdleTimeout(rawSeconds: 3600)
  public static let never = RelayIdleTimeout(rawSeconds: -1)

  public static let defaultTimeout = RelayIdleTimeout.twoMinutes

  public static let presets: [RelayIdleTimeout] = [
    .twoMinutes,
    .fiveMinutes,
    .tenMinutes,
    .fifteenMinutes,
    .thirtyMinutes,
    .oneHour,
    .never
  ]

  public static let presetSeconds: Set<Int> = Set(presets.map(\.rawSeconds))

  public var title: String {
    if isNever {
      return "Never (Stay armed)"
    }
    if rawSeconds % 3600 == 0 {
      let hours = rawSeconds / 3600
      return hours == 1 ? "1 hour" : "\(hours) hours"
    }
    if rawSeconds % 60 == 0 {
      let minutes = rawSeconds / 60
      return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
    return "\(rawSeconds) seconds"
  }

  public var formattedDuration: String {
    if isNever {
      return "never"
    }
    if rawSeconds % 3600 == 0 {
      let hours = rawSeconds / 3600
      return hours == 1 ? "1 hour" : "\(hours) hours"
    }
    if rawSeconds % 60 == 0 {
      let minutes = rawSeconds / 60
      return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
    return "\(rawSeconds) seconds"
  }
}
