import XCTest
@testable import GeminiVoice

final class ModelDownloadManagerTests: XCTestCase {
  var temporaryDirectory: URL!
  var manager: ModelDownloadManager!

  override func setUp() async throws {
    try await super.setUp()
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    temporaryDirectory = temp
    manager = await MainActor.run {
      ModelDownloadManager(storageDirectory: temp, minimumModelFileSize: 10, isBackground: false)
    }
  }

  override func tearDown() async throws {
    if let temp = temporaryDirectory {
      try? FileManager.default.removeItem(at: temp)
    }
    manager = nil
    temporaryDirectory = nil
    try await super.tearDown()
  }

  @MainActor
  func testDefaultDownloadURLIsPublicNonGated() {
    let urlString = ModelDownloadManager.defaultModelDownloadURL.absoluteString
    XCTAssertFalse(
      urlString.contains("google/gemma-2-2b-it-GGUF"),
      "Default download URL must not point to gated repository requiring authentication"
    )
    XCTAssertTrue(
      urlString.contains("litert-community/gemma-4-E2B-it-litert-lm"),
      "Must point to accessible litert-community repository"
    )
    XCTAssertEqual(
      ModelDownloadManager.defaultModelFileName,
      "gemma-4-E2B-it.litert-lm"
    )
  }

  @MainActor
  func testBackgroundSessionIdentifiersAndConfiguration() {
    let bgManager = ModelDownloadManager(
      storageDirectory: temporaryDirectory,
      minimumModelFileSize: 10,
      isBackground: true,
      sessionIdentifier: "test.bg.session.\(UUID().uuidString)"
    )
    XCTAssertTrue(bgManager.isBackground)
    XCTAssertEqual(
      ModelDownloadManager.defaultBackgroundSessionIdentifier,
      "com.example.GeminiVoiceSample.modelDownload"
    )
  }

  @MainActor
  func testStartDownloadDoesNotCrash() {
    let bgManager = ModelDownloadManager(
      storageDirectory: temporaryDirectory,
      minimumModelFileSize: 10,
      isBackground: true,
      sessionIdentifier: "test.bg.session.\(UUID().uuidString)"
    )
    bgManager.startDownload()
    if case .downloading = bgManager.state {
      // Success: download initiated without crashing
    } else {
      XCTFail("Expected state to be downloading, got \(bgManager.state)")
    }
    bgManager.cancelDownload()
  }

  @MainActor
  func testInitialStateIsNotDownloadedWhenFileDoesNotExist() {
    XCTAssertEqual(manager.state, .notDownloaded)
    XCTAssertFalse(manager.isModelReady)
  }

  @MainActor
  func testTinyOrCorruptedFileIsPurgedAutomatically() throws {
    let managerWithStrictLimit = ModelDownloadManager(
      storageDirectory: temporaryDirectory,
      minimumModelFileSize: 1_000_000,
      isBackground: false
    )
    let targetURL = temporaryDirectory.appendingPathComponent(ModelDownloadManager.defaultModelFileName)
    let tinyErrorText = "Access to model litert-community/gemma-4-E2B-it-litert-lm is restricted.".data(using: .utf8)!
    try tinyErrorText.write(to: targetURL)

    managerWithStrictLimit.checkExistingModel()
    XCTAssertFalse(managerWithStrictLimit.isModelReady)
    XCTAssertEqual(managerWithStrictLimit.state, .notDownloaded)
    XCTAssertFalse(FileManager.default.fileExists(atPath: targetURL.path), "Corrupted/tiny file must be purged")
  }

  @MainActor
  func testStateIsReadyWhenFileExists() throws {
    let targetURL = temporaryDirectory.appendingPathComponent(ModelDownloadManager.defaultModelFileName)
    let dummyData = "GemmaWeights".data(using: .utf8)!
    try dummyData.write(to: targetURL)

    manager.checkExistingModel()
    XCTAssertTrue(manager.isModelReady)
    if case .ready(let size, let url) = manager.state {
      XCTAssertEqual(size, Int64(dummyData.count))
      XCTAssertEqual(url, targetURL)
    } else {
      XCTFail("Expected state to be ready")
    }
  }

  @MainActor
  func testDeleteModelRemovesFileAndResetsState() throws {
    let targetURL = temporaryDirectory.appendingPathComponent(ModelDownloadManager.defaultModelFileName)
    try "Weights12345".data(using: .utf8)!.write(to: targetURL)
    manager.checkExistingModel()
    XCTAssertTrue(manager.isModelReady)

    manager.deleteModel()
    XCTAssertFalse(manager.isModelReady)
    XCTAssertEqual(manager.state, .notDownloaded)
    XCTAssertFalse(FileManager.default.fileExists(atPath: targetURL.path))
  }

  @MainActor
  func testBackgroundCompletionHandlerRegistrationAndInvocation() async {
    let testIdentifier = "test-completion-id-\(UUID().uuidString)"
    let expectation = XCTestExpectation(description: "Completion handler invoked")

    ModelDownloadManager.setBackgroundCompletionHandler({ @MainActor in
      expectation.fulfill()
    }, for: testIdentifier)

    ModelDownloadManager.invokeBackgroundCompletionHandler(for: testIdentifier)

    await fulfillment(of: [expectation], timeout: 2.0)
  }
}
