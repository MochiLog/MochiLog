import Foundation

struct DeviceCatalogCache {
  let url: URL

  static var standard: DeviceCatalogCache {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return DeviceCatalogCache(url: root.appendingPathComponent("DeviceCatalog/catalog.signed.json"))
  }

  func load(publicKey: Data? = nil) throws -> DeviceCatalog? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
    guard size <= DeviceCatalog.maximumBytes else { throw DeviceCatalog.CatalogError.invalidData }
    let catalog = try DeviceCatalog.verified(Data(contentsOf: url), publicKey: publicKey)
    return catalog.revision >= DeviceCatalog.bundledRevision ? catalog : nil
  }

  func save(_ data: Data, current: DeviceCatalog?, publicKey: Data? = nil) throws -> DeviceCatalog {
    let incoming = try DeviceCatalog.verified(data, publicKey: publicKey)
    let minimum = max(DeviceCatalog.bundledRevision, current?.revision ?? 0)
    guard incoming.revision >= minimum else { throw DeviceCatalog.CatalogError.rollback }
    if let current, incoming.revision == current.revision, incoming != current {
      throw DeviceCatalog.CatalogError.revisionCollision
    }
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableDirectory = directory
    try mutableDirectory.setResourceValues(values)
    try data.write(to: url, options: .atomic)
    return incoming
  }
}
