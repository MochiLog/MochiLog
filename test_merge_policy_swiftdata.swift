import SwiftData
import CoreData

@available(iOS 17, *)
func test() {
  let schema = Schema([])
  let config = ModelConfiguration()
  let container = try! ModelContainer(for: schema, configurations: [config])

  // Is there a way to get NSManagedObjectContext from ModelContext?
}
