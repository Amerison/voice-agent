import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    else { return }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )
    window.makeKeyAndVisible()
    self.window = window
    // Plugins that look up the app delegate's window still find this one.
    appDelegate.window = window
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    // The engine accepts a new view controller only after the old one is gone.
    window = nil
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.window = nil
    }
  }
}
