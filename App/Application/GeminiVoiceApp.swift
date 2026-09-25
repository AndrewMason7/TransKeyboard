import SwiftUI

@main
struct GeminiVoiceApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase
  @State private var configuration: AppConfiguration
  @State private var relay: RelayController

  init() {
    #if DEBUG
      if ProcessInfo.processInfo.environment["GEMINI_VOICE_NONFATAL_DIAGNOSTIC"] == "1" {
        NSLog("IOS_VALIDATION_FAILURE deliberate nonfatal launch diagnostic")
      }
    #endif
    let configuration = AppConfiguration()
    _configuration = State(wrappedValue: configuration)
    _relay = State(
      wrappedValue: RelayController(configuration: configuration)
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView(configuration: configuration, relay: relay)
        .task {
          guard scenePhase == .active else { return }
          await handleActiveSceneIfEnabled()
        }
        .onChange(of: scenePhase) { _, newPhase in
          switch newPhase {
          case .active:
            Task { await handleActiveSceneIfEnabled() }
          case .background:
            relay.applicationDidEnterBackground()
          case .inactive:
            break
          @unknown default:
            break
          }
        }
    }
  }

  @MainActor
  private func handleActiveSceneIfEnabled() async {
    let environment = ProcessInfo.processInfo.environment
    guard environment["GEMINI_VOICE_DISABLE_RELAY_AUTOSTART"] != "1" else { return }
    #if DEBUG
      guard environment["XCTestConfigurationFilePath"] == nil else { return }
    #endif
    await relay.applicationDidBecomeActive()
  }
}
