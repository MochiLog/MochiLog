import SwiftUI
import UIKit

// Synthetic app only. The fixed variant compiles the production entry point and
// SceneWindowHost; legacy variants recreate saved sessions from both lifecycles.
func trace(_ event: String) {
  let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("events.txt")
  let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  try? (old + event + "\n").write(to: url, atomically: true, encoding: .utf8)
}

func seedRecord() {
  UserDefaults.standard.set("retained-user-record", forKey: "fixture")
  let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("record.json")
  try! Data("{\"id\":42,\"capacity\":3000}".utf8).write(to: url)
}

#if URL_SENDER
  @main
  struct URLSenderApplication: App {
    var body: some Scene {
      WindowGroup {
        Text("Send a synthetic deep link")
          .onAppear {
            guard let value = ProcessInfo.processInfo.environment["SCENE_OPEN_URL"],
              let url = URL(string: value)
            else { return }
            UIApplication.shared.open(url)
          }
      }
    }
  }
#elseif LEGACY_SWIFTUI
  @main
  struct OriginalApplication: App {
    init() { seedRecord() }
    var body: some Scene { WindowGroup { MochiLogWindowContent() } }
  }
#elseif LEGACY_UIKIT
  @main
  final class UIKitEntry: MochiLogApp {}
#endif

class MochiLogApp: UIResponder, UIApplicationDelegate {
  static func route(_ urls: [URL]) {
    for url in urls {
      trace("url=\(url.absoluteString)")
      UserDefaults.standard.set(url.absoluteString, forKey: "lastURL")
      NotificationCenter.default.post(
        name: Notification.Name("ProbeURL"), object: url.absoluteString)
    }
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    #if LEGACY_UIKIT
      seedRecord()
    #endif
    trace("launch marker=\(UserDefaults.standard.string(forKey: "fixture") ?? "nil")")
    return true
  }

  func application(
    _ application: UIApplication, configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: "MochiLog Main Scene", sessionRole: session.role)
    configuration.sceneClass = UIWindowScene.self
    configuration.delegateClass = MochiLogSceneDelegate.self
    return configuration
  }
}

final class MochiLogSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) {
    guard let scene = scene as? UIWindowScene else { return }
    #if LEGACY_UIKIT
      let window = UIWindow(windowScene: scene)
      window.rootViewController = UIHostingController(rootView: MochiLogWindowContent())
      self.window = window
      window.makeKeyAndVisible()
    #else
      window = SceneWindowHost.restoreUIKitWindow(
        in: scene, delegate: self, content: { MochiLogWindowContent() })
    #endif
    trace("connected host=\(window == nil ? "SwiftUI" : "UIKit")")
    record(options.urlContexts)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    let windows = (scene as? UIWindowScene)?.windows ?? []
    let contentWindows = windows.filter {
      guard let root = $0.rootViewController else { return false }
      return String(describing: type(of: root)).contains("UIHostingController")
    }
    trace("active contentWindows=\(contentWindows.count) allWindows=\(windows.count)")
  }

  func sceneDidEnterBackground(_ scene: UIScene) { trace("background") }

  func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    record(contexts)
  }

  private func record(_ contexts: Set<UIOpenURLContext>) {
    MochiLogApp.route(contexts.map(\.url))
  }
}

struct MochiLogWindowContent: View {
  @State private var lastURL = UserDefaults.standard.string(forKey: "lastURL") ?? "none"
  var body: some View {
    VStack {
      Text("Scene lifecycle regression fixture")
      Text(lastURL).accessibilityIdentifier("probe.lastURL")
    }
    .onAppear { trace("content appeared") }
    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProbeURL"))) {
      lastURL = $0.object as? String ?? "none"
    }
  }
}
