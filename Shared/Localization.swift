import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
  case system, japanese = "ja", english = "en", simplifiedChinese = "zh-Hans"
  case traditionalChinese = "zh-Hant", korean = "ko", spanish = "es", french = "fr", german = "de"

  nonisolated var id: String { rawValue }
  nonisolated var name: String {
    switch self {
    case .system: return L10n.string("language_system", table: "Language")
    case .japanese: return "日本語"
    case .english: return "English"
    case .simplifiedChinese: return "简体中文"
    case .traditionalChinese: return "繁體中文"
    case .korean: return "한국어"
    case .spanish: return "Español"
    case .french: return "Français"
    case .german: return "Deutsch"
    }
  }
}

@MainActor
final class LanguageSettings: ObservableObject {
  static let shared = LanguageSettings()
  @Published var selection: AppLanguage {
    didSet { UserDefaults.standard.set(selection.rawValue, forKey: L10n.preferenceKey) }
  }
  init() {
    selection =
      AppLanguage(rawValue: UserDefaults.standard.string(forKey: L10n.preferenceKey) ?? "system")
      ?? .system
  }
}

enum L10n {
  nonisolated static let preferenceKey = "appLanguage"
  nonisolated static let supportedLanguages = [
    "en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de",
  ]

  nonisolated static var language: String {
    resolve(
      selection: UserDefaults.standard.string(forKey: preferenceKey),
      preferredLanguages: Locale.preferredLanguages)
  }

  nonisolated static func resolve(selection: String?, preferredLanguages: [String]) -> String {
    if let selection, supportedLanguages.contains(selection) { return selection }
    return Bundle.preferredLocalizations(
      from: supportedLanguages, forPreferences: preferredLanguages
    ).first ?? "en"
  }

  nonisolated static var locale: Locale { Locale(identifier: language) }

  nonisolated static var bundle: Bundle {
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
      let localizedBundle = Bundle(path: path)
    else { return .main }
    return localizedBundle
  }

  nonisolated static func string(
    _ key: String.LocalizationValue, table: String? = nil,
    comment: StaticString? = nil
  ) -> String {
    String(localized: key, table: table, bundle: bundle, locale: locale, comment: comment)
  }

  nonisolated static func string(
    _ key: StaticString, defaultValue: String.LocalizationValue,
    table: String? = nil, comment: StaticString? = nil
  ) -> String {
    String(
      localized: key, defaultValue: defaultValue, table: table, bundle: bundle, locale: locale,
      comment: comment)
  }

  nonisolated static func text(_ key: String, table: String? = nil) -> String {
    bundle.localizedString(forKey: key, value: nil, table: table)
  }
}
