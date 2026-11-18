import XCTest

final class SceneLifecycleTests: XCTestCase {
  func testRealFileImportPersistsAfterRelaunch() throws {
    guard #available(iOS 16.4, *),
      let fixtures = ProcessInfo.processInfo.environment["MOCHI_IMPORT_TEST_URLS"],
      let simulator = ProcessInfo.processInfo.environment["SIMULATOR_UDID"],
      let data = fixtures.data(using: .utf8),
      let paths = try JSONDecoder().decode([String: [String]].self, from: data)[simulator]
    else { throw XCTSkip("Run with synthetic files on the dedicated import simulators") }
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "-hasCompletedTutorial", "YES", "-iCloudSyncEnabled", "NO",
      "-showPopupOnLoad", "NO", "-showingSampleData", "NO",
      "-allowDuplicateRecords", "NO", "-selectedTabIndex", "0",
      "-LastKnownAppVersion", "4.1.1", "-pcAutomaticCollectionEnabled", "NO",
      "-localAutomaticCollectionEnabled", "NO", "-appLanguage", "en",
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
    ]
    for (index, path) in paths.enumerated() {
      app.open(URL(fileURLWithPath: path))
      let share = app.buttons["record.share"].firstMatch
      XCTAssertTrue(share.waitForExistence(timeout: 20), app.debugDescription)
      app.terminate()
      app.launch()
      let records = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "home.record."))
      XCTAssertTrue(records.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
      XCTAssertEqual(records.count, index + 1, app.debugDescription)
    }
    app.terminate()
  }

  func testHomeSurvivesBackgroundAndRelaunch() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["MOCHI_DUPLICATE_REVIEW_TEST"] = "1"
    app.launchArguments = [
      "-hasCompletedTutorial", "YES", "-iCloudSyncEnabled", "NO",
      "-showPopupOnLoad", "NO", "-showingSampleData", "NO",
      "-allowDuplicateRecords", "YES", "-selectedTabIndex", "0",
      "-LastKnownAppVersion", "4.1.0", "-pcAutomaticCollectionEnabled", "NO",
      "-localAutomaticCollectionEnabled", "NO",
    ]
    let record = app.buttons["home.record.10000000-0000-0000-0000-000000000001"]
    app.launch()
    XCTAssertTrue(record.waitForExistence(timeout: 20), app.debugDescription)
    for _ in 0..<3 {
      // Activating another app also works on Duo simulator runtimes whose
      // simulated Home button can leave the scene in the foreground.
      XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
      XCTAssertTrue(
        app.wait(for: .runningBackground, timeout: 2)
          || app.state == .runningBackgroundSuspended,
        "Unexpected app state after switching apps: \(app.state.rawValue)")
      app.activate()
      XCTAssertTrue(record.waitForExistence(timeout: 10), app.debugDescription)
    }
    app.terminate()
    app.launch()
    XCTAssertTrue(record.waitForExistence(timeout: 20), app.debugDescription)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Home after scene restoration"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.terminate()
  }
}
