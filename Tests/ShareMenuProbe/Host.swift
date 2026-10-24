import UIKit

@main
struct ShareMenuProbe {
  static func main() {
    UIApplicationMain(
      CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(Delegate.self))
  }
}

final class Delegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication, configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "Probe", sessionRole: session.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = ProbeController()
    window.makeKeyAndVisible()
    self.window = window
  }
}

final class ProbeController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let title = UILabel()
    title.text = "共有メニュー検証（合成ログ）"
    title.font = .preferredFont(forTextStyle: .title2)
    title.numberOfLines = 0
    let note = UILabel()
    note.text = "MochiLogとは別のアプリから、OS標準の共有メニューを開きます。実データは使いません。"
    note.numberOfLines = 0
    let stack = UIStackView(arrangedSubviews: [title, note])
    stack.axis = .vertical
    stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    for count in [1, 2, 8, 100, 101] {
      let button = UIButton(type: .system)
      button.setTitle("\(count)件のログを共有", for: .normal)
      button.accessibilityIdentifier = "shareProbe.\(count)"
      button.tag = count
      button.addTarget(self, action: #selector(share(_:)), for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
    ])
  }

  @objc private func share(_ sender: UIButton) {
    do {
      let seedURL = Bundle.main.url(forResource: "valid-iphone", withExtension: "ips")!
      let seed = try String(contentsOf: seedURL, encoding: .utf8)
      let root = FileManager.default.temporaryDirectory.appendingPathComponent("ShareProbe")
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      let files = try (0..<sender.tag).map { index -> URL in
        let folder = root.appendingPathComponent(String(index))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = ["ips", "ips.ca.synced", "log", "txt"][index % 4]
        let file = folder.appendingPathComponent("Analytics-Synthetic.\(ext)")
        let date = Calendar(identifier: .gregorian).date(
          byAdding: .day, value: -index, to: Date(timeIntervalSince1970: 1_792_886_400))!
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        try seed.replacingOccurrences(of: "2026-09-01", with: formatter.string(from: date)).write(
          to: file, atomically: true, encoding: .utf8)
        return file
      }
      let activity = UIActivityViewController(activityItems: files, applicationActivities: nil)
      activity.popoverPresentationController?.sourceView = sender
      activity.popoverPresentationController?.sourceRect = sender.bounds
      present(activity, animated: true)
    } catch {
      let alert = UIAlertController(
        title: "Fixture error", message: error.localizedDescription, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
    }
  }
}
