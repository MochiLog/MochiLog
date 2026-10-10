import UIKit

extension DailyLogCollectionPolicy {
  // Reading the Watch policy does not initialize PC credentials or subscriptions.
  @MainActor static func currentExpectedWatchCount() -> Int? {
    if UIDevice.current.userInterfaceIdiom == .pad { return 0 }
    return expectedWatchCount(isPad: false,
      isWatchPaired: WatchConnectivityManager.shared.isWatchPaired,
      registeredCount: AppSettings.shared.registeredWatches.count)
  }
}
