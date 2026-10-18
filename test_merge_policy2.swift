import SwiftData
import Foundation

@available(iOS 17, *)
func test() {
  let schema = Schema([])
  let config = ModelConfiguration()
  let container = try! ModelContainer(for: schema, configurations: [config])
  let context = container.mainContext
  print(context.mergePolicy)
}
