import Foundation
import Observation

@Observable
@MainActor
final class AppConfiguration {
  enum Key {
    static let apiKeyOverride = "configuration.gemini-api-key-override"
    static let translationTargetCode = TranslationPreferenceKey.targetCode
    static let speechEngineMode = SpeechEngineMode.sharedDefaultsKey
    static let activeModelIdentifier = SpeechEngineMode.activeModelIdentifierKey
    static let autoStartRelayOnLaunch = "configuration.auto-start-relay-on-launch"
    static let autoStopRelayOnBackground = "configuration.auto-stop-relay-on-background"
    static let liveTranscriptionModel = "configuration.live-transcription-model"
  }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let sharedDefaults: UserDefaults
  @ObservationIgnored private let credentialStore: GeminiCredentialStore
  @ObservationIgnored private let embeddedAPIKey: String
  @ObservationIgnored private let embeddedTranscriptionModel: String
  @ObservationIgnored private let embeddedOCRModel: String
  @ObservationIgnored private let embeddedTranslationModel: String

  var liveTranscriptionModel: String {
    didSet {
      let trimmed = liveTranscriptionModel.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolved = trimmed.isEmpty ? GeminiLiveSpeechSession.defaultTranscriptionModel : trimmed
      if resolved != liveTranscriptionModel {
        liveTranscriptionModel = resolved
      }
      defaults.set(resolved, forKey: Key.liveTranscriptionModel)
    }
  }

  public static let availableTranscriptionModels: [String] = [
    "gemini-3.5-transcribe-live",
    "gemini-3.5-transcribe",
    ModelDownloadManager.defaultModelFileName
  ]

  var selectedModelId: String {
    get {
      let saved = defaults.string(forKey: Key.activeModelIdentifier)
        ?? sharedDefaults.string(forKey: Key.activeModelIdentifier)
      if let saved, !saved.isEmpty {
        return saved
      }
      switch speechEngineMode {
      case .geminiLive, .autoFallback:
        return SpeechEngineMode.defaultModelIdentifier
      case .geminiBatch:
        return "gemini-3.5-transcribe"
      case .localOnDevice:
        return ModelDownloadManager.defaultModelFileName
      }
    }
    set {
      let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolved = trimmed.isEmpty ? SpeechEngineMode.defaultModelIdentifier : trimmed
      speechEngineMode = SpeechEngineMode.mode(for: resolved)
      if speechEngineMode == .geminiLive {
        liveTranscriptionModel = resolved
      }
      defaults.set(resolved, forKey: Key.activeModelIdentifier)
      sharedDefaults.set(resolved, forKey: Key.activeModelIdentifier)
      sharedDefaults.synchronize()
    }
  }

  var activeTranscriptionModelDisplay: String {
    selectedModelId
  }

  var speechEngineMode: SpeechEngineMode {
    didSet {
      defaults.set(speechEngineMode.rawValue, forKey: Key.speechEngineMode)
      sharedDefaults.set(speechEngineMode.rawValue, forKey: Key.speechEngineMode)
      sharedDefaults.synchronize()

      let currentModel = selectedModelId
      if SpeechEngineMode.mode(for: currentModel) != speechEngineMode {
        let newModel: String
        switch speechEngineMode {
        case .geminiLive, .autoFallback:
          newModel = SpeechEngineMode.defaultModelIdentifier
        case .geminiBatch:
          newModel = "gemini-3.5-transcribe"
        case .localOnDevice:
          newModel = ModelDownloadManager.defaultModelFileName
        }
        defaults.set(newModel, forKey: Key.activeModelIdentifier)
        sharedDefaults.set(newModel, forKey: Key.activeModelIdentifier)
        sharedDefaults.synchronize()
      }
    }
  }

  var apiKeyOverride: String {
    didSet {
      if credentialStore.saveAPIKey(apiKeyOverride) {
        defaults.removeObject(forKey: Key.apiKeyOverride)
        credentialPersistenceWarning = nil
      } else {
        credentialPersistenceWarning =
          "The credential is usable for this session but could not be saved to Keychain."
      }
      // The keyboard and Live Activity never need the API key. Remove
      // any legacy App Group copy after migrating to Keychain.
      sharedDefaults.removeObject(forKey: Key.apiKeyOverride)
      sharedDefaults.synchronize()
    }
  }

  private(set) var credentialPersistenceWarning: String?

  var translationTargetCode: String {
    didSet {
      let resolved = TranslationLanguage.language(for: translationTargetCode)
      if resolved.code != translationTargetCode {
        translationTargetCode = resolved.code
      }
      defaults.set(resolved.code, forKey: Key.translationTargetCode)
      sharedDefaults.set(resolved.code, forKey: Key.translationTargetCode)
      sharedDefaults.synchronize()
    }
  }

  var autoStartRelayOnLaunch: Bool {
    didSet {
      defaults.set(autoStartRelayOnLaunch, forKey: Key.autoStartRelayOnLaunch)
    }
  }

  var autoStopRelayOnBackground: Bool {
    didSet {
      defaults.set(autoStopRelayOnBackground, forKey: Key.autoStopRelayOnBackground)
    }
  }

  init(
    defaults: UserDefaults = .standard,
    sharedDefaults: UserDefaults? = nil,
    bundle: Bundle = .main,
    credentialStore: GeminiCredentialStore = GeminiCredentialStore()
  ) {
    let resolvedSharedDefaults = sharedDefaults ?? (defaults == .standard ? (UserDefaults(suiteName: VoiceAppGroup.identifier) ?? defaults) : defaults)
    self.defaults = defaults
    self.sharedDefaults = resolvedSharedDefaults
    self.credentialStore = credentialStore
    self.embeddedAPIKey =
      (bundle.object(forInfoDictionaryKey: "GeminiDefaultAPIKey") as? String) ?? ""
    self.embeddedTranscriptionModel = Self.nonEmptyBundleString(
      bundle,
      key: "GeminiDefaultTranscriptionModel",
      fallback: "gemini-3.5-transcribe"
    )
    self.embeddedOCRModel = Self.nonEmptyBundleString(
      bundle,
      key: "GeminiDefaultOCRModel",
      fallback: "gemini-3.8-flash"
    )
    self.embeddedTranslationModel = Self.nonEmptyBundleString(
      bundle,
      key: "GeminiDefaultTranslationModel",
      fallback: "gemini-3.5-flash"
    )
    let legacyOverride = defaults.string(forKey: Key.apiKeyOverride) ?? ""
    let securedOverride = credentialStore.loadAPIKey()
    self.apiKeyOverride = securedOverride.isEmpty ? legacyOverride : securedOverride
    self.credentialPersistenceWarning = nil
    let savedEngineMode =
      defaults.string(forKey: Key.speechEngineMode)
      ?? resolvedSharedDefaults.string(forKey: Key.speechEngineMode)
    let resolvedEngineMode = savedEngineMode.flatMap(SpeechEngineMode.init(rawValue:)) ?? .defaultMode
    self.speechEngineMode = resolvedEngineMode
    let savedLiveModel = defaults.string(forKey: Key.liveTranscriptionModel)?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.liveTranscriptionModel = (savedLiveModel?.isEmpty == false) ? savedLiveModel! : GeminiLiveSpeechSession.defaultTranscriptionModel
    self.autoStartRelayOnLaunch = defaults.object(forKey: Key.autoStartRelayOnLaunch) as? Bool ?? true
    self.autoStopRelayOnBackground = defaults.object(forKey: Key.autoStopRelayOnBackground) as? Bool ?? false

    let savedTargetCode =
      defaults.string(forKey: Key.translationTargetCode)
      ?? resolvedSharedDefaults.string(forKey: Key.translationTargetCode)
      ?? TranslationLanguage.defaultLanguage.code
    self.translationTargetCode = TranslationLanguage.language(for: savedTargetCode).code

    let savedModelIdentifier =
      defaults.string(forKey: Key.activeModelIdentifier)
      ?? resolvedSharedDefaults.string(forKey: Key.activeModelIdentifier)
    let initialModel = (savedModelIdentifier?.isEmpty == false) ? savedModelIdentifier! : SpeechEngineMode.defaultModelIdentifier
    defaults.set(initialModel, forKey: Key.activeModelIdentifier)
    resolvedSharedDefaults.set(initialModel, forKey: Key.activeModelIdentifier)
    resolvedSharedDefaults.set(resolvedEngineMode.rawValue, forKey: Key.speechEngineMode)
    resolvedSharedDefaults.synchronize()

    resolvedSharedDefaults.removeObject(forKey: Key.apiKeyOverride)
    if securedOverride.isEmpty, !legacyOverride.isEmpty {
      if credentialStore.saveAPIKey(legacyOverride) {
        defaults.removeObject(forKey: Key.apiKeyOverride)
      } else {
        credentialPersistenceWarning = "The existing credential could not be moved to Keychain yet."
      }
    } else {
      defaults.removeObject(forKey: Key.apiKeyOverride)
    }
    resolvedSharedDefaults.set(self.translationTargetCode, forKey: Key.translationTargetCode)
    resolvedSharedDefaults.synchronize()
  }

  var apiKey: String {
    let override = apiKeyOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    return override.isEmpty ? embeddedAPIKey : override
  }

  var transcriptionModel: String {
    embeddedTranscriptionModel
  }

  var liveTranslationModel: String {
    GeminiLiveSpeechSession.translationModel
  }

  var ocrModel: String {
    embeddedOCRModel
  }

  var translationModel: String {
    embeddedTranslationModel
  }

  var translationTarget: TranslationLanguage {
    TranslationLanguage.language(for: translationTargetCode)
  }

  var hasUsableAPIKey: Bool {
    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    return !key.isEmpty
      && key != "YOUR_GEMINI_API_KEY"
      && key != "__GEMINI_API_KEY__"
  }

  var embeddedKeyDescription: String {
    let key = embeddedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty,
      key != "YOUR_GEMINI_API_KEY",
      key != "__GEMINI_API_KEY__"
    else {
      return "No embedded key"
    }
    return "Extractable Debug credential configured — personal-device use only"
  }

  func clearAPIKeyOverride() {
    apiKeyOverride = ""
  }

  private static func nonEmptyBundleString(
    _ bundle: Bundle,
    key: String,
    fallback: String
  ) -> String {
    let configured =
      (bundle.object(forInfoDictionaryKey: key) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return configured.isEmpty ? fallback : configured
  }
}
