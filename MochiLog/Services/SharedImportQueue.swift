import Combine
import Foundation

/// Owns incoming URLs until a visible HomeView can consume them. No transient notifications.
@MainActor
final class SharedImportQueue: ObservableObject {
  static let shared = SharedImportQueue()
  @Published private(set) var revision = 0
  @Published var results: [FileImportResult] = []
  private var pending: [URL] = []
  private var known: Set<URL> = []
  private var scopes: [URL: [URL]] = [:]
  private var sourceDeviceIDs: [URL: UUID] = [:]
  private var recentlyCompleted: [URL: Date] = [:]
  private(set) var isConsuming = false
  private(set) var shouldPresentResults = false
  private(set) var shouldOpenDetail = false
  private let now: () -> Date

  init(now: @escaping () -> Date = Date.init) { self.now = now }

  func enqueue(_ url: URL, accessRoots: [URL] = [], presentsResults: Bool = true, opensDetail: Bool = false, physicalDeviceID: UUID? = nil) {
    recentlyCompleted = recentlyCompleted.filter { now().timeIntervalSince($0.value) < 2 }
    guard recentlyCompleted[url] == nil else { return }
    guard url.isFileURL, known.insert(url).inserted else { return }
    scopes[url] = ([url] + accessRoots).filter { $0.startAccessingSecurityScopedResource() }
    sourceDeviceIDs[url] = physicalDeviceID
    shouldPresentResults = shouldPresentResults || presentsResults
    shouldOpenDetail = shouldOpenDetail || opensDetail
    pending.append(url)
    AppSettings.shared.selectedTabIndex = 0
    revision += 1
  }

  func begin() -> Bool {
    guard !isConsuming, !pending.isEmpty else { return false }
    isConsuming = true
    return true
  }

  func takeNext() -> [URL] {
    let result = pending
    pending.removeAll()
    return result
  }

  func physicalDeviceID(for url: URL) -> UUID? { sourceDeviceIDs[url] }

  func finish() {
    isConsuming = false
    shouldPresentResults = false
    shouldOpenDetail = false
  }

  func acknowledge(_ url: URL, saved: Bool = false) {
    if let root = SharedLogInbox.root {
      try? SharedLogInbox.acknowledge(url, saved: saved, at: root)
    }
    if saved, let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("Inbox", isDirectory: true) {
      let path = url.standardizedFileURL.resolvingSymlinksInPath().path
      if path.hasPrefix(inbox.standardizedFileURL.resolvingSymlinksInPath().path + "/") {
        try? FileManager.default.removeItem(at: url)
      }
    }
    if saved, let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      let macInbox = documents.appendingPathComponent("MacTransferInbox", isDirectory: true)
        .standardizedFileURL.resolvingSymlinksInPath().path + "/"
      let path = url.standardizedFileURL.resolvingSymlinksInPath().path
      if path.hasPrefix(macInbox) { try? FileManager.default.removeItem(at: url) }
    }
    for scope in scopes.removeValue(forKey: url) ?? [] { scope.stopAccessingSecurityScopedResource() }
    sourceDeviceIDs.removeValue(forKey: url)
    known.remove(url)
    recentlyCompleted[url] = now()
    // Failed/review inputs and provider originals remain available for retry.
  }
}

enum LogTextReader {
  nonisolated static func read(_ url: URL) throws -> String {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    var coordinationError: NSError?
    var result: Result<String, Error> = .failure(CocoaError(.fileReadUnknown))
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
      result = Result {
        let data = try Data(contentsOf: readable, options: .mappedIfSafe)
        let encodings: [String.Encoding] = [.utf8, .utf16, .shiftJIS, .isoLatin1]
        for encoding in encodings {
          // UTF-16 without a BOM can incorrectly decode arbitrary legacy bytes.
          if encoding == .utf16 && !data.starts(with: [0xFF, 0xFE]) && !data.starts(with: [0xFE, 0xFF]) { continue }
          if let text = String(data: data, encoding: encoding) { return text }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
      }
    }
    if let coordinationError { throw coordinationError }
    return try result.get()
  }
}
