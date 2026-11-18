import SwiftUI
import UIKit

/// Keep an AppGraph available when iOS restores a scene saved by the original
/// SwiftUI app. A UIKit-only entry point can launch successfully, then trap in
/// AppSceneDelegate.stateRestorationActivity when that old scene backgrounds.
@main
struct MochiLogApplication: App {
  @UIApplicationDelegateAdaptor(MochiLogApp.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      MochiLogWindowContent()
        .onOpenURL { MochiLogApp.route([$0]) }
    }
  }
}
