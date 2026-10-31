import CryptoKit
import Foundation

enum L10n {
  static let language = "en"
  static func string(_ key: String, table: String) -> String { key }
  static func string(_ key: String.LocalizationValue, table: String) -> String { "validation" }
}
final class AppSettings {
  static let shared = AppSettings()
  var overrideLocalModelIdentifier = ""
}

@main
struct DeviceCatalogTests {
  static let key = Curve25519.Signing.PrivateKey()
  static var publicKey: Data { key.publicKey.rawRepresentation }
  static let future = DeviceProfile(
    id: "catalog:future-ipad", name: "iPad Future Test", identifiers: ["iPad99,1"],
    capacity: 5000, soc: "Future Test", boards: ["TEST99AP": "iPad99,1"])

  static func catalog(
    revision: Int = DeviceCatalog.bundledRevision + 1,
    profiles: [DeviceProfile] = [future], schema: Int = 1
  ) -> DeviceCatalog {
    DeviceCatalog(schemaVersion: schema, revision: revision, profiles: profiles)
  }

  static func signed(_ catalog: DeviceCatalog, key: Curve25519.Signing.PrivateKey = key) throws
    -> Data
  {
    let payload = try JSONEncoder().encode(catalog)
    return try JSONEncoder().encode(
      DeviceCatalog.Envelope(
        payload: payload.base64EncodedString(),
        signature: key.signature(for: payload).base64EncodedString()))
  }

  static func reject(_ operation: () throws -> Void) {
    do { try operation(); preconditionFailure("Expected rejection") } catch {}
  }

  @MainActor
  static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let suite = "MochiLog.CatalogTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let cache = DeviceCatalogCache(url: root.appendingPathComponent("catalog.json"))
    defer {
      try? FileManager.default.removeItem(at: root)
      defaults.removePersistentDomain(forName: suite)
    }
    let original = catalog()
    let valid = try signed(original)
    precondition((try? DeviceCatalog.verified(valid, publicKey: publicKey)) == original)
    let alien = Curve25519.Signing.PrivateKey()
    reject { _ = try DeviceCatalog.verified(valid, publicKey: alien.publicKey.rawRepresentation) }
    let wrongSigner = try signed(original, key: alien)
    reject { _ = try DeviceCatalog.verified(wrongSigner, publicKey: publicKey) }
    var envelope = try JSONDecoder().decode(DeviceCatalog.Envelope.self, from: valid)
    envelope = DeviceCatalog.Envelope(
      payload: Data("{}".utf8).base64EncodedString(), signature: envelope.signature)
    let tampered = try JSONEncoder().encode(envelope)
    reject { _ = try DeviceCatalog.verified(tampered, publicKey: publicKey) }
    reject {
      _ = try DeviceCatalog.verified(
        Data(repeating: 0, count: DeviceCatalog.maximumBytes + 1), publicKey: publicKey)
    }
    let unsupported = try signed(catalog(schema: 2))
    reject { _ = try DeviceCatalog.verified(unsupported, publicKey: publicKey) }
    var invalid = future
    invalid.capacity = -1
    reject { try catalog(profiles: [invalid]).validate() }
    invalid = future; invalid.identifiers = ["iPad99,1", "bad-id"]
    reject { try catalog(profiles: [invalid]).validate() }
    invalid = future; invalid.id = "duplicate"
    reject { try catalog(profiles: [future, invalid]).validate() }
    invalid = future; invalid.id = "second"; invalid.name = "Second";
    invalid.identifiers = ["iPad99,2"]
    invalid.boards = ["TEST99AP": "iPad99,2"]
    reject { try catalog(profiles: [future, invalid]).validate() }
    print("PASS: authentic signatures, wrong keys, tampering, size, schema and conflicting data")

    let accepted = try cache.save(valid, current: nil, publicKey: publicKey)
    precondition((try? cache.load(publicKey: publicKey)) == original)
    let older = try signed(catalog(revision: original.revision - 1))
    reject { _ = try cache.save(older, current: accepted, publicKey: publicKey) }
    invalid = future; invalid.capacity = 5100
    let collision = try signed(catalog(profiles: [invalid]))
    reject { _ = try cache.save(collision, current: accepted, publicKey: publicKey) }
    reject { _ = try cache.save(tampered, current: accepted, publicKey: publicKey) }
    precondition((try? cache.load(publicKey: publicKey)) == original)
    print("PASS: signed cache reload, rollback/collision rejection and last-good preservation")

    let store = DeviceProfileStore(defaults: defaults)
    var custom = store.profiles.first { $0.name == "iPad mini (A17 Pro)" }!
    custom.capacity = 4800
    try store.save(custom)
    let savedEntries = store.entries
    try store.apply(catalog: original)
    precondition(store.names["iPad99,1"] == future.name)
    precondition(store.capacity(future.name) == 5000)
    precondition(store.capacity("iPad mini (A17 Pro)") == 4800)
    precondition(
      store.names["iPhone18,3"] != nil, "An overlay cannot silently remove bundled devices")
    precondition(store.entries == savedEntries, "Remote updates never rewrite manual entries")
    var changedStandard = DeviceProfileStore.bundled.first { $0.name == custom.name }!
    changedStandard.capacity = 5100
    let changed = catalog(revision: original.revision + 1, profiles: [future, changedStandard])
    try store.apply(catalog: changed)
    precondition(store.capacity(custom.name) == 4800)
    precondition(store.conflicts.contains { $0.current.name == custom.name })
    let restarted = DeviceProfileStore(defaults: defaults, catalog: changed)
    precondition(restarted.capacity(custom.name) == 4800)
    precondition(restarted.names["iPad99,1"] == future.name)
    precondition(restarted.entries == savedEntries)
    print("PASS: new-device resolution, bundled fallback, manual settings, conflicts and restart")

    let freshCache = DeviceCatalogCache(url: root.appendingPathComponent("fresh/catalog.json"))
    let freshStore = DeviceProfileStore(defaults: defaults)
    precondition(freshStore.names["iPad99,1"] == nil)
    var returnTamperedData = false
    let freshUpdater = DeviceCatalogUpdater(
      defaults: defaults, store: freshStore, cache: freshCache, publicKey: publicKey
    ) { _ in
      DeviceCatalogDownload.Result(bytes: returnTamperedData ? tampered : valid, etag: nil)
    }
    let discovered = await freshUpdater.checkForUnknownModel("iPad99,1")
    precondition(discovered && freshUpdater.dataRevision == original.revision)
    precondition(freshStore.names["iPad99,1"] == future.name)
    precondition(freshStore.capacity(future.name) == 5000)
    precondition(freshStore.capacity(custom.name) == 4800)
    let successfulCheck = freshUpdater.lastChecked
    returnTamperedData = true
    _ = await freshUpdater.check()
    precondition(freshUpdater.messageKey == "catalog_failed")
    precondition(freshUpdater.lastChecked == successfulCheck)
    precondition(freshStore.names["iPad99,1"] == future.name)
    precondition((try? freshCache.load(publicKey: publicKey)) == original)
    defaults.removeObject(forKey: "deviceCatalog.lastUnknownAttempt")
    print(
      "PASS: unknown model fetch activates signed data; a later bad response preserves active data")

    var requests = 0
    let updater = DeviceCatalogUpdater(
      defaults: defaults, store: store, cache: cache, publicKey: publicKey
    ) { _ in
      requests += 1
      try await Task.sleep(nanoseconds: 40_000_000)
      return DeviceCatalogDownload.Result(bytes: valid, etag: "test-v1")
    }
    async let first = updater.check()
    async let second = updater.check()
    _ = await (first, second)
    precondition(requests == 1, "Concurrent imports and settings share a request")
    precondition(updater.lastChecked != nil && !updater.isChecking)
    await updater.checkIfDue()
    precondition(requests == 1, "Successful checks sleep for 24 hours")
    updater.automaticUpdates = false
    _ = await updater.checkForUnknownModel("iPad100,1")
    await updater.checkIfDue()
    precondition(requests == 1, "Opt-out applies to unknown models too")
    _ = await updater.check()
    precondition(requests == 2, "Manual checks work while automatic updates are off")
    print("PASS: shared request, daily schedule, opt-out and manual checks")

    defaults.removeObject(forKey: "deviceCatalog.lastAttempt")
    updater.automaticUpdates = true
    var failures = 0
    let failed = DeviceCatalogUpdater(
      defaults: defaults, store: store, cache: cache, publicKey: publicKey
    ) { _ in
      failures += 1
      throw URLError(.notConnectedToInternet)
    }
    _ = await failed.check()
    await failed.checkIfDue()
    precondition(failures == 1 && failed.messageKey == "catalog_failed")
    precondition((try? cache.load(publicKey: publicKey)) == original)
    _ = await failed.checkForUnknownModel("iPad100,1")
    _ = await failed.checkForUnknownModel("iPad100,2")
    precondition(failures == 2, "Unknown-model attempts are bounded across devices")
    let relaunched = DeviceCatalogUpdater(
      defaults: defaults, store: store, cache: cache, publicKey: publicKey
    ) { _ in
      failures += 1
      throw URLError(.notConnectedToInternet)
    }
    _ = await relaunched.checkForUnknownModel("iPad101,1")
    precondition(failures == 2, "Restarting must not bypass the unknown-model retry interval")
    print("PASS: offline preservation and bounded failed/unknown-model retries across restarts")

    var conditionalRequests = 0
    let conditional = DeviceCatalogUpdater(
      defaults: defaults, store: store, cache: cache, publicKey: publicKey
    ) { etag in
      precondition(etag == "test-v1")
      conditionalRequests += 1
      return DeviceCatalogDownload.Result(bytes: nil, etag: etag)
    }
    _ = await conditional.check()
    precondition(conditionalRequests == 1 && conditional.messageKey == "catalog_current")
    print("PASS: conditional unchanged responses retain verified data")
  }
}
