import SwiftUI

// MARK: - 設定カテゴリ
enum SettingsCategory: String, CaseIterable, Identifiable {
  case general
  case iCloud
  case appleWatch
  case dataManagement
  case support
  case debug
  case automaticCollection
  case advanced
  case about
  case language

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .language: return "globe"
    case .general: return "gearshape.fill"
    case .iCloud: return "icloud.fill"
    case .appleWatch: return "applewatch"
    case .dataManagement: return "trash.fill"
    case .support: return "book.fill"
    case .about: return "info.circle"
    case .debug: return "envelope.fill"
    case .automaticCollection: return "arrow.down.document.fill"
    case .advanced: return "gearshape.2.fill"
    }
  }

  var title: String {
    switch self {
    case .language: return L10n.string("language_title", table: "Language")
    case .general: return L10n.string("general", table: "Settings")
    case .iCloud: return L10n.string("icloud_sync_settings", defaultValue: "iCloud Sync", table: "Settings")
    case .appleWatch: return "Apple Watch"
    case .dataManagement: return L10n.string("data_management", table: "Settings")
    case .support: return L10n.string("support", table: "Settings")
    case .about: return L10n.string("about_app", table: "Settings")
    case .debug: return L10n.string("debug", table: "Support")
    case .automaticCollection: return L10n.text("auto_collection_title", table: "MacTransfer")
    case .advanced: return L10n.string("advanced_settings", table: "Settings")
    }
  }
}
