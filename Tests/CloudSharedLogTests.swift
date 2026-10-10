import CryptoKit
import Foundation

@main struct CloudSharedLogTests {
  static func main() {
    // Completed daily receipts do not block the first capability/consent probe.
    precondition(CloudSharingCapability.shouldProbe(advertised: false, secureRequired: true, unsupported: false))
    precondition(CloudSharingCapability.shouldProbe(advertised: false, secureRequired: nil, unsupported: false))
    precondition(!CloudSharingCapability.shouldProbe(advertised: false, secureRequired: false, unsupported: false))
    precondition(!CloudSharingCapability.shouldProbe(advertised: false, secureRequired: true, unsupported: true))
    precondition(CloudSharingCapability.shouldProbe(advertised: true, secureRequired: true, unsupported: true))
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
    let phone = UUID(), pad = UUID(), receiver = "iPad16,6"
    let knownModels = [phone: "iPhone18,3", pad: receiver]
    precondition(LogSourceIdentity.resolve(detected: nil, source: phone, known: knownModels,
      local: receiver, foreign: true) == "iPhone18,3")
    precondition(LogSourceIdentity.resolve(detected: nil, source: pad, known: knownModels,
      local: "iPhone18,3", foreign: true) == receiver)
    precondition(LogSourceIdentity.resolve(detected: nil, source: UUID(), known: knownModels,
      local: receiver, foreign: true) == nil) // unknown foreign source never becomes this iPad
    precondition(LogSourceIdentity.resolve(detected: "iPhone18,3", source: UUID(), known: [:],
      local: receiver, foreign: true) == "iPhone18,3")
    precondition(LogSourceIdentity.resolve(detected: receiver, source: phone, known: knownModels,
      local: receiver, foreign: true) == nil) // contradictory authenticated origin requires review
    precondition(LogSourceIdentity.resolve(detected: nil, source: nil, known: [:],
      local: receiver, foreign: false) == receiver) // ordinary direct import remains compatible
    let mistaken = CloudSharedLogToken.recordID(origin: phone, digest: digest)
    precondition(LogSourceIdentity.shouldRepair(recordID: mistaken, origin: phone, model: receiver,
      known: knownModels) == "iPhone18,3")
    precondition(LogSourceIdentity.shouldRepair(recordID: mistaken, origin: phone, model: "iPhone18,3",
      known: knownModels) == nil) // idempotent on every cloud replica
    precondition(LogSourceIdentity.shouldRepair(recordID: UUID(), origin: phone, model: receiver,
      known: knownModels) == nil) // no automatic reassignment of manual/legacy records
    precondition(LogSourceIdentity.shouldRepair(recordID: mistaken, origin: nil, model: receiver,
      known: knownModels) == nil)
    precondition(LogSourceIdentity.shouldRepair(recordID: mistaken, origin: watch, model: "Watch7,18",
      known: knownModels) == nil)
    precondition(LogSourceIdentity.shouldRepair(recordID: mistaken, origin: phone, model: "A3385",
      known: knownModels) == nil) // phone-owned MagSafe battery must remain distinct
    precondition(LogSourceIdentity.shouldRepair(recordID: mistaken, origin: phone, model: nil,
      known: knownModels) == nil) // unclassified/legacy records require explicit review
    print("PASS: authenticated source models, foreign fallback rejection and non-destructive identity repair")
    print("PASS: origin tokens, traversal rejection, Watch separation, stable record IDs and non-destructive four-device coalescence")
  }
}
