import CryptoKit
import Foundation

@main struct CloudSharedLogTests {
  static func main() {
    let origin = UUID(), other = UUID(), scope = String(repeating: "a", count: 64)
    let base = "Host::Analytics-2026-10-08-090000.ips.ca.synced"
    let value = CloudSharedLogToken(scope: scope, origin: origin, base: base)
    precondition(!CloudSharedLogToken.debugLabel(value.value).contains(scope))
    precondition(CloudSharedLogToken.debugLabel(value.value).contains(origin.uuidString))
    precondition(CloudSharedLogToken.debugLabel("Shared::" + scope + "::bad") == "Shared[invalid token]")
    precondition(!CloudSharedLogToken.debugLabel("Host::\nAnalytics-a.ips.ca.synced").contains("\n"))
    precondition(CloudSharedLogToken.parse(value.value)?.origin == origin)
    precondition(CloudSharedLogToken.parse(value.value)?.base == base)
    for invalid in ["Shared::" + scope + "::" + origin.uuidString + "::Host::../Analytics-x.ips.ca.synced",
      "Shared::" + scope + "::" + origin.uuidString + "::Host::Analytics-x\\bad.ips.ca.synced",
      "Shared::bad::" + origin.uuidString + "::" + base,
      "Shared::" + scope + "::" + origin.uuidString + "::Host::Analytics-session.ips.ca.synced"] {
      precondition(CloudSharedLogToken.parse(invalid) == nil)
    }
    let digest = SHA256.hash(data: Data("same file".utf8)).map { String(format: "%02x", $0) }.joined()
    let id = CloudSharedLogToken.recordID(origin: origin, digest: digest)
    precondition(id == CloudSharedLogToken.recordID(origin: origin, digest: digest))
    precondition(id != CloudSharedLogToken.recordID(origin: other, digest: digest))
    precondition(id != CloudSharedLogToken.recordID(origin: origin, digest: String(repeating: "b", count: 64)))
    let watch = CloudSharedLogToken.measurementOrigin(base: "Watch::ProxiedDevice-a1::Analytics-x.ips.ca.synced", origin: origin)!
    precondition(watch != origin && watch != CloudSharedLogToken.measurementOrigin(base: "Watch::ProxiedDevice-b2::Analytics-x.ips.ca.synced", origin: origin))
    precondition(CloudSharedLogToken.measurementOrigin(base: base, origin: origin) == origin)
    struct Row { let id: UUID; let origin: UUID?; let date: Date; let localizedName: String }
    let a = Row(id: id, origin: origin, date: Date(timeIntervalSince1970: 100), localizedName: "iPad 日本語")
    let b = Row(id: id, origin: origin, date: a.date, localizedName: "iPad English")
    let raw = [a, b, a, b]
    let merged = CloudSharedLogToken.coalesced(raw, id: { $0.id }, origin: { $0.origin }, date: { $0.date })
    precondition(raw.count == 4 && merged.count == 1) // no underlying cloud-object deletion
    precondition(CloudSharedLogToken.coalesced(raw.reversed(), id: { $0.id }, origin: { $0.origin }, date: { $0.date }).count == 1)
    let legacyID = UUID()
    let legacy = Row(id: legacyID, origin: origin, date: a.date, localizedName: "legacy")
    let separate = Row(id: id, origin: other, date: a.date, localizedName: "another device")
    let untagged = Row(id: id, origin: nil, date: a.date, localizedName: "legacy untagged")
    precondition(CloudSharedLogToken.coalesced([a, separate, legacy, legacy, untagged], id: { $0.id }, origin: { $0.origin }, date: { $0.date }).count == 5)
    struct Copy { let id: UUID; let origin: UUID?; let date: Date; let createdAt: Date }
    let first = Copy(id: id, origin: origin, date: a.date, createdAt: Date(timeIntervalSince1970: 1))
    let second = Copy(id: id, origin: origin, date: a.date, createdAt: Date(timeIntervalSince1970: 2))
    func discarded(_ rows: [Copy]) -> [Copy] {
      CloudSharedLogToken.redundantCopies(rows, id: { $0.id }, origin: { $0.origin }, date: { $0.date }, createdAt: { $0.createdAt })
    }
    precondition(discarded([first, second]).map(\.createdAt) == [second.createdAt])
    precondition(discarded([second, first]).map(\.createdAt) == [second.createdAt])
    precondition(discarded([first]).isEmpty && discarded([second]).isEmpty)
    precondition(discarded([first, first]).isEmpty) // equal timestamps never choose different keepers
    let later = Copy(id: id, origin: origin, date: a.date, createdAt: Date(timeIntervalSince1970: 3))
    precondition(discarded([later, second]).map(\.createdAt) == [later.createdAt])
    precondition(discarded([later, second, first]).map(\.createdAt) == [later.createdAt, second.createdAt])
    print("PASS: origin tokens, traversal rejection, Watch separation, stable record IDs and non-destructive four-device coalescence")
  }
}
