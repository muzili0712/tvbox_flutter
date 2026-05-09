import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🚀 AppDelegate.application called")

        GeneratedPluginRegistrant.register(with: self)

        print("✅ Plugins registered")

        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

        print("✅ Application launched successfully")

        return result
    }
}
