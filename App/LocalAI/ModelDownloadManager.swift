import Foundation
import Observation
import os

@Observable
@MainActor
public final class ModelDownloadManager: NSObject, URLSessionDownloadDelegate, Sendable {
  public nonisolated static let defaultModelFileName = "gemma-4-E2B-it.litert-lm"
  public nonisolated static let defaultModelDownloadURL = URL(
    string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
  )!
  public nonisolated static let defaultMinimumModelFileSize: Int64 = 1_000_000_000
  public nonisolated static let defaultBackgroundSessionIdentifier = "com.example.GeminiVoiceSample.modelDownload"

  public enum DownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case ready(fileSize: Int64, fileURL: URL)
    case failed(String)
  }

  public private(set) var state: DownloadState = .notDownloaded

  public var isModelReady: Bool {
    if case .ready = state { return true }
    return false
  }

  @ObservationIgnored public nonisolated let storageDirectory: URL
  @ObservationIgnored public nonisolated let minimumModelFileSize: Int64
  @ObservationIgnored public nonisolated let isBackground: Bool
  @ObservationIgnored public nonisolated let sessionIdentifier: String
  @ObservationIgnored private var downloadTask: URLSessionDownloadTask?
  @ObservationIgnored private nonisolated let lastProgressEmitTime = OSAllocatedUnfairLock<TimeInterval>(initialState: 0)

  // Background completion handlers registered by UIKit AppDelegate
  private nonisolated static let backgroundCompletionHandlers = OSAllocatedUnfairLock<[String: @Sendable @MainActor () -> Void]>(initialState: [:])
  private static weak var activeInstance: ModelDownloadManager?

  @ObservationIgnored private lazy var session: URLSession = {
    let config: URLSessionConfiguration
    if isBackground {
      config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
      config.sessionSendsLaunchEvents = true
      config.isDiscretionary = false
      config.waitsForConnectivity = true
    } else {
      config = URLSessionConfiguration.default
    }
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  public init(
    storageDirectory: URL? = nil,
    minimumModelFileSize: Int64 = defaultMinimumModelFileSize,
    isBackground: Bool = true,
    sessionIdentifier: String = defaultBackgroundSessionIdentifier
  ) {
    let dir: URL
    if let storageDirectory {
      dir = storageDirectory
    } else {
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      dir = appSupport.appendingPathComponent("LocalModels", isDirectory: true)
    }
    self.storageDirectory = dir
    self.minimumModelFileSize = minimumModelFileSize
    self.isBackground = isBackground
    self.sessionIdentifier = sessionIdentifier
    super.init()
    Self.activeInstance = self
    try? FileManager.default.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
    checkExistingModel()
    if isBackground && !isModelReady {
      reconnectExistingDownloadTasks()
    }
  }

  public nonisolated var modelFileURL: URL {
    storageDirectory.appendingPathComponent(Self.defaultModelFileName)
  }

  public func checkExistingModel() {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: modelFileURL.path) {
      if let attributes = try? fileManager.attributesOfItem(atPath: modelFileURL.path),
         let size = attributes[.size] as? Int64,
         size >= minimumModelFileSize {
        state = .ready(fileSize: size, fileURL: modelFileURL)
        return
      } else {
        // File exists but is smaller than minimum required model size (e.g. an HTML/JSON error page).
        // Automatically purge it so it doesn't leave the app in a broken state.
        try? fileManager.removeItem(at: modelFileURL)
      }
    }
    state = .notDownloaded
  }

  public func reconnectExistingDownloadTasks() {
    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      let downloadTasks = tasks.compactMap { $0 as? URLSessionDownloadTask }
      guard let activeTask = downloadTasks.first(where: {
        $0.state == .running || $0.state == .suspended
      }) else { return }

      Task { @MainActor in
        self.downloadTask = activeTask
        let received = activeTask.countOfBytesReceived
        let expected = activeTask.countOfBytesExpectedToReceive
        let progress = expected > 0 ? Double(received) / Double(expected) : 0.0
        if case .notDownloaded = self.state {
          self.state = .downloading(
            progress: progress,
            bytesWritten: received,
            totalBytes: expected
          )
        }
      }
    }
  }

  public func startDownload(from url: URL = defaultModelDownloadURL) {
    cancelDownload()
    state = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: 0)
    let task = session.downloadTask(with: url)
    downloadTask = task
    task.resume()
  }

  public func cancelDownload() {
    downloadTask?.cancel()
    downloadTask = nil
    checkExistingModel()
  }

  public func deleteModel() {
    cancelDownload()
    try? FileManager.default.removeItem(at: modelFileURL)
    state = .notDownloaded
  }

  // MARK: - Background Completion Handler Registration

  public nonisolated static func setBackgroundCompletionHandler(_ handler: @escaping @Sendable @MainActor () -> Void, for identifier: String) {
    backgroundCompletionHandlers.withLock { handlers in
      handlers[identifier] = handler
    }
  }

  public nonisolated static func invokeBackgroundCompletionHandler(for identifier: String?) {
    guard let identifier else { return }
    let handler = backgroundCompletionHandlers.withLock { handlers in
      handlers.removeValue(forKey: identifier)
    }
    if let handler {
      Task { @MainActor in
        handler()
      }
    }
  }

  // MARK: - URLSessionDownloadDelegate

  nonisolated public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    let now = ProcessInfo.processInfo.systemUptime
    let isFinished = totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite
    let shouldEmit = lastProgressEmitTime.withLock { lastTime -> Bool in
      if isFinished || (now - lastTime) >= 0.1 {
        lastTime = now
        return true
      }
      return false
    }

    if shouldEmit {
      let progress = totalBytesExpectedToWrite > 0
        ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        : 0.0
      Task { @MainActor in
        self.state = .downloading(
          progress: progress,
          bytesWritten: totalBytesWritten,
          totalBytes: totalBytesExpectedToWrite
        )
      }
    }
  }

  nonisolated public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    if let httpResponse = downloadTask.response as? HTTPURLResponse,
       !(200...299).contains(httpResponse.statusCode) {
      let code = httpResponse.statusCode
      let errorBody = (try? String(contentsOf: location, encoding: .utf8)) ?? ""
      let reason = errorBody.isEmpty
        ? HTTPURLResponse.localizedString(forStatusCode: code)
        : errorBody.prefix(120).trimmingCharacters(in: .whitespacesAndNewlines)
      Task { @MainActor in
        self.state = .failed("HTTP \(code): \(reason)")
      }
      return
    }

    let downloadedSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
    guard downloadedSize >= self.minimumModelFileSize else {
      Task { @MainActor in
        self.state = .failed("Downloaded file too small (\(downloadedSize) bytes). Model corrupted or truncated.")
      }
      return
    }

    let target = self.modelFileURL
    do {
      try? FileManager.default.removeItem(at: target)
      try FileManager.default.moveItem(at: location, to: target)
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      var url = target
      try url.setResourceValues(resourceValues)
      Task { @MainActor in
        self.checkExistingModel()
      }
    } catch {
      Task { @MainActor in
        self.state = .failed("Failed to save downloaded model: \(error.localizedDescription)")
      }
    }
  }

  nonisolated public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    if let error = error as? URLError, error.code == .cancelled {
      return
    }
    if let error {
      Task { @MainActor in
        self.state = .failed(error.localizedDescription)
      }
    }
  }

  nonisolated public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    Self.invokeBackgroundCompletionHandler(for: session.configuration.identifier)
  }
}
