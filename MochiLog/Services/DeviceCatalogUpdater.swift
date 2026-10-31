import Combine
import Foundation
import OSLog

/// All callers share one request and one retry clock, including multi-file imports.
@MainActor
final class DeviceCatalogUpdater: ObservableObject {
  static let shared = DeviceCatalogUpdater()
  nonisolated static let endpoint = URL(
    string:
      "https://raw.githubusercontent.com/MochiLog/MochiLog/main/device-catalog/catalog.signed.json")!
  private static let logger = Logger(subsystem: "net.ryuya-dev.MochiLog", category: "DeviceCatalog")

  @Published private(set) var isChecking = false
  @Published private(set) var messageKey: String?
  @Published private(set) var lastChecked: Date?
  @Published private(set) var dataRevision: Int
  @Published var automaticUpdates: Bool {
    didSet { defaults.set(automaticUpdates, forKey: "deviceCatalog.automaticUpdates") }
  }

  private let defaults: UserDefaults
  private let store: DeviceProfileStore
  private let cache: DeviceCatalogCache
  private let publicKey: Data?
  private let download: (String?) async throws -> DeviceCatalogDownload.Result
  private var current: DeviceCatalog?
  private var requestTask: Task<Bool, Never>?
  private var lastUnknownAttempt: Date?

  init(
    defaults: UserDefaults = .standard, store: DeviceProfileStore? = nil,
    cache: DeviceCatalogCache? = nil, publicKey: Data? = nil,
    download: @escaping (String?) async throws -> DeviceCatalogDownload.Result =
      DeviceCatalogDownload.fetch
  ) {
    self.defaults = defaults
    self.store = store ?? .shared
    self.cache = cache ?? .standard
    self.publicKey = publicKey
    self.download = download
    current = (try? self.cache.load(publicKey: publicKey)).flatMap { candidate in
      (try? candidate.standards(over: DeviceProfileStore.bundled)) == nil ? nil : candidate
    }
    dataRevision = current?.revision ?? DeviceCatalog.bundledRevision
    lastChecked = defaults.object(forKey: "deviceCatalog.lastChecked") as? Date
    lastUnknownAttempt = defaults.object(forKey: "deviceCatalog.lastUnknownAttempt") as? Date
    automaticUpdates =
      defaults.object(forKey: "deviceCatalog.automaticUpdates") == nil
      ? true : defaults.bool(forKey: "deviceCatalog.automaticUpdates")
  }

  func checkIfDue() async {
    guard automaticUpdates else { return }
    let lastAttempt = defaults.object(forKey: "deviceCatalog.lastAttempt") as? Date
    let interval: TimeInterval = lastChecked == lastAttempt ? 86400 : 3600
    guard lastAttempt.map({ Date().timeIntervalSince($0) >= interval }) ?? true else { return }
    _ = await check()
  }

  func checkForUnknownModel(_ identifier: String) async -> Bool {
    guard automaticUpdates,
      identifier.range(of: "^(iPhone|iPad|Watch|iPod)[0-9]+,[0-9]+$", options: .regularExpression)
        != nil,
      store.names[identifier] == nil
    else { return false }
    if let requestTask {
      markUnknownAttempt()
      return await requestTask.value
    }
    guard lastUnknownAttempt.map({ Date().timeIntervalSince($0) >= 3600 }) ?? true else {
      return false
    }
    markUnknownAttempt()
    return await check()
  }

  private func markUnknownAttempt() {
    let date = Date()
    lastUnknownAttempt = date
    defaults.set(date, forKey: "deviceCatalog.lastUnknownAttempt")
  }

  @discardableResult
  func check() async -> Bool {
    if let requestTask { return await requestTask.value }
    isChecking = true
    messageKey = nil
    let task = Task { await self.fetch() }
    requestTask = task
    let result = await task.value
    requestTask = nil
    isChecking = false
    return result
  }

  private func fetch() async -> Bool {
    let attempt = Date()
    defaults.set(attempt, forKey: "deviceCatalog.lastAttempt")
    Self.logger.info("Check started, revision=\(self.dataRevision)")
    do {
      let previous = current
      let data = try await download(
        current == nil ? nil : defaults.string(forKey: "deviceCatalog.etag"))
      if let bytes = data.bytes {
        let verified = try DeviceCatalog.verified(bytes, publicKey: publicKey)
        // Validate the whole effective catalog before replacing the last good file.
        _ = try verified.standards(over: DeviceProfileStore.bundled)
        let accepted = try cache.save(bytes, current: current, publicKey: publicKey)
        current = accepted
        try store.apply(catalog: accepted)
        dataRevision = accepted.revision
      }
      if let etag = data.etag { defaults.set(etag, forKey: "deviceCatalog.etag") }
      lastChecked = attempt
      defaults.set(attempt, forKey: "deviceCatalog.lastChecked")
      let updated = current != previous && dataRevision > DeviceCatalog.bundledRevision
      messageKey = updated ? "catalog_updated" : "catalog_current"
      Self.logger.info("Check succeeded, revision=\(self.dataRevision), changed=\(updated)")
      return updated
    } catch {
      messageKey = "catalog_failed"
      Self.logger.error(
        "Check rejected or unavailable: \(String(describing: error), privacy: .public); retained revision=\(self.dataRevision)"
      )
      return false
    }
  }
}

enum DeviceCatalogDownload {
  struct Result {
    let bytes: Data?
    let etag: String?
  }

  /// Stream with a strict bound so an oversized response cannot exhaust memory.
  static func fetch(etag: String?) async throws -> Result {
    var request = URLRequest(url: DeviceCatalogUpdater.endpoint)
    request.timeoutInterval = 15
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForResource = 30
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let (bytes, response) = try await session.bytes(for: request)
    guard let response = response as? HTTPURLResponse,
      response.url?.scheme == "https", response.url?.host == DeviceCatalogUpdater.endpoint.host
    else { throw URLError(.badServerResponse) }
    if response.statusCode == 304, etag != nil {
      return Result(bytes: nil, etag: etag)
    }
    guard response.statusCode == 200,
      response.expectedContentLength <= DeviceCatalog.maximumBytes
    else { throw URLError(.badServerResponse) }
    var data = Data()
    for try await byte in bytes {
      guard data.count < DeviceCatalog.maximumBytes else {
        throw URLError(.dataLengthExceedsMaximum)
      }
      data.append(byte)
    }
    return Result(bytes: data, etag: response.value(forHTTPHeaderField: "ETag"))
  }
}
