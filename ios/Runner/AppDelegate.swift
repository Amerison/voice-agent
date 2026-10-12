import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Owned here rather than by a view controller so it outlives scene
  // disconnects; SceneDelegate attaches each new window to it.
  lazy var flutterEngine = FlutterEngine(name: "main")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
