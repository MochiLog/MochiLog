import CloudKit
import Foundation

@main
struct CloudKitErrorTests {
  static func main() {
    let auth = NSError(domain: CKErrorDomain, code: CKError.notAuthenticated.rawValue)
    let network = NSError(domain: CKErrorDomain, code: CKError.networkFailure.rawValue)
    let plain = NSError(domain: "Local", code: 1)
    assert(CloudKitErrorInspector.cloudKitError(in: plain) == nil)
    assert(CloudKitErrorInspector.cloudKitError(in: network)?.code == .networkFailure)
    let wrapped = NSError(domain: "CoreData", code: 1, userInfo: [NSUnderlyingErrorKey: auth])
    assert(CloudKitErrorInspector.cloudKitError(in: wrapped)?.code == .notAuthenticated)
    let multiple = NSError(
      domain: "CoreData", code: 2,
      userInfo: ["NSUnderlyingErrorsKey": [plain, wrapped]])
    assert(CloudKitErrorInspector.cloudKitError(in: multiple)?.code == .notAuthenticated)
    let partial = NSError(
      domain: CKErrorDomain, code: CKError.partialFailure.rawValue,
      userInfo: [CKPartialErrorsByItemIDKey: ["record": multiple]])
    assert(
      CloudKitErrorInspector.cloudKitError(in: partial)?.code == .notAuthenticated,
      "Authentication failures nested in partial failures must remain actionable")
    let otherPartial = NSError(
      domain: CKErrorDomain, code: CKError.partialFailure.rawValue,
      userInfo: [CKPartialErrorsByItemIDKey: ["record": network]])
    assert(CloudKitErrorInspector.cloudKitError(in: otherPartial)?.code == .partialFailure)
    var deep: NSError = auth
    for _ in 0..<100 {
      deep = NSError(domain: "Wrapper", code: 0, userInfo: [NSUnderlyingErrorKey: deep])
    }
    assert(CloudKitErrorInspector.cloudKitError(in: deep) == nil, "Unbounded graphs must stop")
    print(
      "PASS: CloudKit direct, wrapped, multiple and partial errors; authentication priority; bounded traversal"
    )
  }
}
