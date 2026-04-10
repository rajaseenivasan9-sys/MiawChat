import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let windowScene = scene as? UIWindowScene,
           let flutterViewController = windowScene.windows.first?.rootViewController as? FlutterViewController {
            SalesforceMethodChannelHandler.shared.setup(with: flutterViewController.engine)
        }
    }
}
