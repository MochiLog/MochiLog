import Foundation
import CoreData

func extractConflict(error: Error) {
  let nsError = error as NSError
  if nsError.domain == NSCocoaErrorDomain && nsError.code == NSManagedObjectMergeError {
    if let conflicts = nsError.userInfo["conflictList"] as? [NSMergeConflict] {
      for conflict in conflicts {
        print("Local: \(conflict.objectSnapshot)")
        print("Server: \(conflict.cachedSnapshot)")
        print("Database: \(conflict.persistedSnapshot)")
      }
    }
  }
}
