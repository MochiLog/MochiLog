import SwiftUI
import UIKit

/// Existing UIKit sessions retain their window; SwiftUI owns all other windows.
/// Do not delete session archives or touch the user's records to migrate startup.
@MainActor
enum SceneWindowHost {
  static func restoreUIKitWindow<Content: View>(
    in scene: UIWindowScene, delegate: any UIWindowSceneDelegate,
    content: () -> Content
  ) -> UIWindow? {
    guard scene.delegate === delegate else { return nil }
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: content())
    window.makeKeyAndVisible()
    return window
  }
}
