import XCTest
import UIKit

final class LanguageAndLayoutTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [
      "-hasCompletedTutorial", "YES", "-iCloudSyncEnabled", "NO",
      "-LastKnownAppVersion", "3.1.1", "-showPopupOnLoad", "NO",
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
    ]
  }

  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .portrait
    app.terminate()
  }

  func testDuoAspectRatioAndResize() {
    app.launchEnvironment["MOCHI_LAYOUT_TEST"] = "1"
    app.launchArguments += ["-selectedTabIndex", "0"]
    app.launch()
    let sample = app.buttons["View Sample Data"]
    if sample.waitForExistence(timeout: 5) { sample.tap() }
    XCTAssertTrue(app.staticTexts["iPhone 15 Pro"].firstMatch.waitForExistence(timeout: 15))
    screenshot("Duo approximation 800x1120 Home")
    for title in ["Analytics", "Settings"] {
      let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 10))
      tab.tap()
      if title == "Analytics" {
        XCTAssertTrue(app.buttons["chart.range"].firstMatch.waitForExistence(timeout: 10))
      } else {
        XCTAssertTrue(app.buttons["settings.category.general"].waitForExistence(timeout: 10))
      }
      screenshot("Duo approximation 800x1120 " + title)
      app.buttons["layout.mode.1"].tap()
      screenshot("Compact 390x844 " + title)
      app.buttons["layout.mode.2"].tap()
      screenshot("Wide landscape 980x700 " + title)
      app.buttons["layout.mode.0"].tap()
    }
    let home = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Home")).firstMatch
    home.tap()
    let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.record.")).firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 10))
    record.tap()
    let detail = app.navigationBars["Details"]
    XCTAssertTrue(detail.waitForExistence(timeout: 10))
    screenshot("Duo approximation Detail")
    app.buttons["layout.mode.1"].tap()
    XCTAssertTrue(detail.waitForExistence(timeout: 5), "Resizing must preserve the selected record")
    screenshot("Compact Detail after resize")
    app.buttons["layout.mode.0"].tap()
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
  }

  func testHomeDoesNotDuplicateDeviceCards() {
    for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
      app.launchArguments += ["-appLanguage", "en", "-selectedTabIndex", "0",
                              "-UIPreferredContentSizeCategoryName", size]
      app.launch()
      let sample = app.buttons["View Sample Data"]
      if sample.waitForExistence(timeout: 5) { sample.tap() }
      let record = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "home.record.")).firstMatch
      XCTAssertTrue(record.waitForExistence(timeout: 15))
      XCTAssertFalse(app.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "home.deviceSummary.")).firstMatch.exists)
      XCTAssertFalse(app.otherElements["home.librarySummary"].exists)
      record.tap()
      XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 10))
      app.terminate()
    }
  }

  func testMarketplaceDisablesDonations() {
    for source in ["appStore", "marketplace", "testFlight"] {
      app.launchEnvironment["MOCHI_TEST_DISTRIBUTOR"] = source
      app.launchArguments += ["-appLanguage", "en", "-selectedTabIndex", "2"]
      app.launch()
      let settings = app.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", "Settings")).firstMatch
      XCTAssertTrue(settings.waitForExistence(timeout: 10), app.debugDescription)
      settings.tap()
      let support = app.buttons["settings.category.support"]
      if support.waitForExistence(timeout: 5) { support.tap() }
      let donation = app.descendants(matching: .any)["settings.donation"].firstMatch
      for _ in 0..<6 {
        if donation.exists && donation.isHittable { break }
        app.swipeUp()
      }
      XCTAssertEqual(donation.exists, source != "marketplace", source + app.debugDescription)
      app.terminate()
    }
  }

  func testReducedEffectsOverview() {
    app.launchArguments += ["-renderingMode", "reduced"]
    verifyOverview(size: "UICTContentSizeCategoryL")
  }

  // Store capture uses the real sample-data UI, without changing user records.
  func testStoreScreenshotsEnglish() { captureStoreScreens(language: "en", locale: "en_US") }
  func testStoreScreenshotsJapanese() { captureStoreScreens(language: "ja", locale: "ja_JP") }

  private func captureStoreScreens(language: String, locale: String) {
    XCUIDevice.shared.appearance = .dark
    app.launchEnvironment["MOCHI_STORE_SCREENSHOTS"] = "1"
    XCUIDevice.shared.orientation = .portrait
    app.launchArguments = [
      "-hasCompletedTutorial", "YES", "-iCloudSyncEnabled", "NO",
      "-LastKnownAppVersion", "3.2.0", "-showPopupOnLoad", "NO",
      "-appLanguage", language, "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
      "-selectedTabIndex", "0", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
    ]
    app.launch()
    let japanese = language == "ja"
    let sample = app.buttons[japanese ? "サンプルデータを見る" : "View Sample Data"]
    if sample.waitForExistence(timeout: 5) { sample.tap() }
    let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.record.")).firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 15), app.debugDescription)
    if UIDevice.current.userInterfaceIdiom == .phone {
      let watchHeader = app.buttons.matching(NSPredicate(format: "label == %@", "Apple Watch Series 9")).firstMatch
      if watchHeader.isHittable { watchHeader.tap() }
    }
    let phoneRecord: XCUIElement
    if UIDevice.current.userInterfaceIdiom == .pad {
      // Wide cards omit the repeated device name; choose a visible card under its column header.
      let header = app.buttons.matching(NSPredicate(format: "label == %@", "iPhone 14")).firstMatch
      XCTAssertTrue(header.waitForExistence(timeout: 10), app.debugDescription)
      let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.record.")).allElementsBoundByIndex
      guard let card = cards.first(where: {
        $0.isHittable && abs($0.frame.midX - header.frame.midX) < 10 && $0.frame.minY >= header.frame.maxY
      }) else { XCTFail("No visible iPhone 14 card: \(app.debugDescription)"); return }
      phoneRecord = card
    } else {
      phoneRecord = app.buttons.matching(NSPredicate(format:
        "identifier BEGINSWITH %@ AND label CONTAINS %@", "home.record.", "iPhone 14")).firstMatch
    }
    XCTAssertTrue(phoneRecord.waitForExistence(timeout: 10), app.debugDescription)
    Thread.sleep(forTimeInterval: 2)
    screenshot("store_\(locale)_01_home")
    phoneRecord.tap()
    XCTAssertTrue(app.navigationBars[japanese ? "詳細" : "Details"].waitForExistence(timeout: 10), app.debugDescription)
    Thread.sleep(forTimeInterval: 1)
    let detailScroll = app!
    if UIDevice.current.userInterfaceIdiom == .phone {
      detailScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        .press(forDuration: 0.1, thenDragTo: detailScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)),
          withVelocity: .slow, thenHoldForDuration: 0.3)
    }
    Thread.sleep(forTimeInterval: 1)
    screenshot("store_\(locale)_02_details")
    // Relaunch to dismiss both iPhone's sheet and iPad's pushed detail consistently.
    app.terminate(); app.launch()
    if sample.waitForExistence(timeout: 3) { sample.tap() }
    for (index, title) in [("03_analytics", japanese ? "分析" : "Analytics"),
                            ("04_settings", japanese ? "設定" : "Settings")] {
      let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 10), app.debugDescription)
      tab.tap()
      Thread.sleep(forTimeInterval: 2)
      if index == "03_analytics" && UIDevice.current.userInterfaceIdiom == .phone {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
          .press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.60)),
            withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 2)
      }
      screenshot("store_\(locale)_\(index)")
    }
  }

  func testRefreshedOverviewScreens() {
    verifyOverview(size: "UICTContentSizeCategoryL")
  }

  func testRefreshedOverviewAtAccessibilitySize() {
    verifyOverview(size: "UICTContentSizeCategoryAccessibilityXXXL")
  }

  func testRefreshedLandscapeOverview() {
    XCUIDevice.shared.orientation = .landscapeLeft
    verifyOverview(size: "UICTContentSizeCategoryL")
  }

  func testRecordInfoSettingPersists() {
    app.launchArguments += ["-recordInfoDefaultsRelease", "older-release"]
    app.launch()
    app.launchArguments.removeLast(2)
    func openSettings() {
      let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 10))
      tab.tap()
    }
    openSettings()
    let toggle = app.switches["settings.recordInfo"].firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    let original = toggle.value as? String
    XCTAssertEqual(original, "0", "An updated release starts with info buttons OFF")
    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    let changed = toggle.value as? String
    XCTAssertNotEqual(original, changed)
    screenshot("Settings Info Toggle")
    app.terminate()
    app.launch()
    openSettings()
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    XCTAssertEqual(toggle.value as? String, changed)
    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    XCTAssertEqual(toggle.value as? String, original)
  }

  func testStatisticsCards() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Analytics")).firstMatch
    XCTAssertTrue(tab.waitForExistence(timeout: 10))
    tab.tap()
    let statistics = app.otherElements["analytics.statistics"].firstMatch
    for _ in 0..<6 {
      if statistics.exists && statistics.isHittable { break }
      app.swipeUp()
    }
    app.swipeUp()
    XCTAssertTrue(app.staticTexts["Statistics"].firstMatch.exists)
    screenshot("Device Statistics")
  }

  func testLanguageAtBottom() {
    app.launch()
    openLanguage()
    XCTAssertTrue(app.buttons["language.en"].exists)
    screenshot("Language Settings at Bottom")
  }

  func testSettingsSidebarRemainsVisible() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    openLanguage()
    let watch = app.buttons["settings.category.appleWatch"]
    screenshot("Language Sidebar")
    XCTAssertTrue(watch.exists, app.debugDescription)
    let sidebar = app.scrollViews.containing(.button, identifier: "settings.language").firstMatch
    if !watch.isHittable { sidebar.swipeDown() }
    watch.tap()
    screenshot("Watch Settings Sidebar")
    XCTAssertTrue(app.buttons["settings.language"].exists)
    app.buttons["settings.category.advanced"].tap()
    screenshot("Advanced Light Settings")
  }

  func testDeviceProfileEditAndRestore() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    let settings = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10))
    settings.tap()
    let advanced = app.buttons["settings.category.advanced"].exists
      ? app.buttons["settings.category.advanced"] : app.buttons["settings.advanced"]
    for _ in 0..<8 {
      if advanced.isHittable { break }
      app.swipeUp()
    }
    advanced.tap()
    let library = app.buttons["settings.deviceProfiles"]
    XCTAssertTrue(library.waitForExistence(timeout: 10))
    library.tap()
    let search = app.textFields["profiles.search"]
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap(); search.typeText("iPhone 15 Pro")
    let model = app.buttons["profiles.model.bundled:iPhone 15 Pro"]
    XCTAssertTrue(model.waitForExistence(timeout: 5)); model.tap()
    let capacity = app.textFields["profiles.capacity"]
    XCTAssertTrue(capacity.waitForExistence(timeout: 5))
    let original = capacity.value as! String
    capacity.tap()
    capacity.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count) + "4000")
    if app.buttons["Close"].exists { app.buttons["Close"].tap() }
    app.swipeUp()
    func tap(_ identifier: String) {
      let button = app.buttons[identifier]
      for _ in 0..<8 { if button.isHittable { break }; app.swipeUp() }
      XCTAssertTrue(button.exists); button.tap()
    }
    tap("profiles.save")
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    app.alerts.buttons["OK"].tap()
    tap("profiles.apply")
    app.alerts.buttons["Apply Saved Values to Logs"].tap()
    XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 10))
    screenshot("Profile Applied")
    app.alerts.buttons["OK"].tap()
    tap("profiles.restore")
    app.alerts.buttons["Restore Initial Values"].tap()
    app.alerts.buttons["OK"].tap()
    tap("profiles.apply")
    app.alerts.buttons["Apply Saved Values to Logs"].tap()
    XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 10))
    app.alerts.buttons["OK"].tap()
    for _ in 0..<8 { if capacity.isHittable { break }; app.swipeDown() }
    XCTAssertEqual(capacity.value as? String, original)
    screenshot("Profile Restored")
  }

  func testChartRangeIndependence() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    if app.buttons["View Sample Data"].exists { app.buttons["View Sample Data"].tap() }
    let analytics = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Analytics")).firstMatch
    XCTAssertTrue(analytics.waitForExistence(timeout: 10)); analytics.tap()
    let health = app.buttons["chart.range"].firstMatch
    XCTAssertTrue(health.waitForExistence(timeout: 10)); health.tap()
    app.buttons["1m"].firstMatch.tap()
    let healthWindow = app.staticTexts["chart.window"].firstMatch.label
    let cycle = app.buttons["chart.cycle.range"].firstMatch
    if UIDevice.current.userInterfaceIdiom == .pad {
      for _ in 0..<5 { if cycle.isHittable { break }; app.swipeUp() }
      XCTAssertTrue(cycle.exists); cycle.tap(); app.buttons["1w"].firstMatch.tap()
      XCTAssertTrue(cycle.label.contains("1w"))
      for _ in 0..<5 { if health.isHittable { break }; app.swipeDown() }
      XCTAssertTrue(health.label.contains("1m"))
      XCTAssertEqual(app.staticTexts["chart.window"].firstMatch.label, healthWindow)
      health.tap(); app.buttons["Auto"].firstMatch.tap()
      XCUIDevice.shared.orientation = .landscapeLeft
      for _ in 0..<5 { if cycle.isHittable { break }; app.swipeUp() }
      XCTAssertTrue(cycle.label.contains("1w"), "Cycle range must survive health changes and rotation")
    } else {
      app.swipeUp()
      XCTAssertFalse(cycle.exists, "iPhone keeps one shared range selector")
    }
    screenshot("Chart Range Independence")
  }

  func testAddDeviceFromLibrary() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    let settings = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
    let advanced = app.buttons["settings.category.advanced"].exists
      ? app.buttons["settings.category.advanced"] : app.buttons["settings.advanced"]
    for _ in 0..<8 { if advanced.isHittable { break }; app.swipeUp() }
    advanced.tap(); app.buttons["settings.deviceProfiles"].tap()
    XCTAssertTrue(app.buttons["profiles.addRow"].waitForExistence(timeout: 10))
    app.buttons["profiles.addRow"].tap()
    let name = "Manual Test " + UUID().uuidString.prefix(8)
    let identifier = "iPhone999," + String(Int(Date().timeIntervalSince1970))
    let field = app.textFields["profiles.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
    app.textFields["profiles.capacity"].tap(); app.textFields["profiles.capacity"].typeText("4000")
    let ids = app.textViews["profiles.identifiers"]
    for _ in 0..<4 { if ids.isHittable { break }; app.swipeUp() }
    ids.tap(); ids.typeText(identifier)
    app.buttons["profiles.addSave"].tap()
    XCTAssertTrue(app.textFields["profiles.search"].waitForExistence(timeout: 5))
    app.terminate(); app.launch(); settings.tap()
    for _ in 0..<8 { if advanced.isHittable { break }; app.swipeUp() }
    advanced.tap(); app.buttons["settings.deviceProfiles"].tap()
    let search = app.textFields["profiles.search"]
    XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(name)
    XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 5))
    screenshot("Manually Added Device")
  }

  func testDeviceCategoriesAndGeneralSettings() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    let settings = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
    if app.buttons["settings.category.general"].exists { app.buttons["settings.category.general"].tap() }
    screenshot("General Settings Unified")
    let advanced = app.buttons["settings.category.advanced"].exists
      ? app.buttons["settings.category.advanced"] : app.buttons["settings.advanced"]
    for _ in 0..<8 { if advanced.isHittable { break }; app.swipeUp() }
    advanced.tap()
    app.buttons["settings.deviceProfiles"].tap()
    XCTAssertTrue(app.textFields["profiles.search"].waitForExistence(timeout: 10))
    for category in ["iPhone", "iPad", "Apple Watch", "iPod", "other"] {
      XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "profiles.category." + category).firstMatch.exists)
    }
    screenshot("Device Categories")
    let search = app.textFields["profiles.search"]
    search.tap(); search.typeText("iPhone 15 Pro")
    XCTAssertTrue(app.buttons["profiles.model.bundled:iPhone 15 Pro"].waitForExistence(timeout: 5))
  }

  private func verifyOverview(size: String) {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
    app.launch()
    if app.buttons["View Sample Data"].exists { app.buttons["View Sample Data"].tap() }
    // A phone list lazily creates rows; the first device can be a Watch.
    let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.record.")).firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 15))
    screenshot("Refreshed Home")
    for title in ["Analytics", "Settings"] {
      let tab = app.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", title)).firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 5), app.debugDescription)
      tab.tap()
      if title == "Analytics" {
        XCTAssertTrue(app.buttons["chart.range"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
      } else {
        XCTAssertTrue(app.switches["settings.recordInfo"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
      }
      screenshot("Refreshed " + title)
    }
  }

  private func openLanguage() {
    if app.buttons["language.en"].exists { return }
    if app.tabBars.buttons.count >= 3 {
      app.tabBars.buttons.element(boundBy: 2).tap()
    } else {
      // iPad's floating tab bar exposes cells in iOS 27.
      let settings = app.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR label == %@", "Settings", "Einstellungen")
      ).firstMatch
      XCTAssertTrue(settings.waitForExistence(timeout: 5), app.debugDescription)
      settings.tap()
    }
    let link = app.buttons["settings.language"]
    for _ in 0..<8 {
      if link.exists && link.isHittable { break }
      let sidebar = app.scrollViews.containing(.button, identifier: "settings.language").firstMatch
      if sidebar.exists { sidebar.swipeUp() } else { app.swipeUp() }
    }
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    link.tap()
    XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 5))
  }

  private func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: name.hasPrefix("store_") ? app.screenshot() : XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func systemLanguageButton() -> XCUIElement {
    let button = app.buttons["language.system"]
    for _ in 0..<8 {
      if button.exists && button.isHittable { break }
      app.swipeDown()
    }
    XCTAssertTrue(button.exists)
    return button
  }

  func testLanguageSelectionPersistsAndUsesDeviceDefault() {
    app.launch()
    openLanguage()
    systemLanguageButton().tap()
    openLanguage()
    XCTAssertTrue(systemLanguageButton().label.contains("Follow device settings"))
    let german = app.buttons["language.de"]
    for _ in 0..<8 {
      if german.isHittable { break }
      app.swipeUp()
    }
    german.tap()
    openLanguage()
    screenshot("German language settings")
    XCTAssertTrue(systemLanguageButton().label.contains("Gerätesprache verwenden"))
    app.terminate()
    app.launch()
    openLanguage()
    XCTAssertTrue(systemLanguageButton().label.contains("Gerätesprache verwenden"))
    systemLanguageButton().tap()
  }

  func testSettingsAtLargeTextAndLandscape() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    openLanguage()
    screenshot("Language settings at largest text size")
    XCUIDevice.shared.orientation = .landscapeLeft
    let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.app.frame.width > self.app.frame.height
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed,
      "The app must actually rotate")
    // Wait for the system rotation animation before capturing the whole display.
    Thread.sleep(forTimeInterval: 1)
    XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 5))
    screenshot("Language settings in landscape")
    XCUIDevice.shared.orientation = .portrait
  }
}
