import Foundation
import CoreData

func test(error: Error) {
  let nsError = error as NSError
  if nsError.domain == NSCocoaErrorDomain && nsError.code == NSManagedObjectMergeError {
    if let conflicts = nsError.userInfo["conflictList"] as? [NSMergeConflict] {
      for conflict in conflicts {
        print(conflict.sourceObject)
      }
    }
  }
}
