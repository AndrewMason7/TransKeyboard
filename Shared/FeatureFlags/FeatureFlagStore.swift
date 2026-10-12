import Foundation
import Observation

@Observable
@MainActor
public final class FeatureFlagStore: Sendable {
  public static let shared = FeatureFlagStore()

  private static let keyPrefix = "featureflag."

  @ObservationIgnored
  private let defaults: UserDefaults

  public init(defaults: UserDefaults? = nil) {
    self.defaults = defaults ?? UserDefaults(suiteName: VoiceAppGroup.identifier) ?? .standard
  }

  public func isEnabled(_ flag: FeatureFlag) -> Bool {
    let key = Self.keyPrefix + flag.rawValue
    guard defaults.object(forKey: key) != nil else {
      return flag.defaultValue
    }
    return defaults.bool(forKey: key)
  }

  public func setEnabled(_ flag: FeatureFlag, isEnabled: Bool) {
    let key = Self.keyPrefix + flag.rawValue
    defaults.set(isEnabled, forKey: key)
    defaults.synchronize()
  }

  public func hasOverride(_ flag: FeatureFlag) -> Bool {
    defaults.object(forKey: Self.keyPrefix + flag.rawValue) != nil
  }

  public func resetOverride(_ flag: FeatureFlag) {
    defaults.removeObject(forKey: Self.keyPrefix + flag.rawValue)
    defaults.synchronize()
  }

  public func resetToDefaults() {
    for flag in FeatureFlag.allCases {
      resetOverride(flag)
    }
  }

  public subscript(flag: FeatureFlag) -> Bool {
    get { isEnabled(flag) }
    set { setEnabled(flag, isEnabled: newValue) }
  }
}
