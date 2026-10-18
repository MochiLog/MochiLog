import SwiftData
@available(iOS 17, *)
func test(context: ModelContext) {
  context.rollback()
}
