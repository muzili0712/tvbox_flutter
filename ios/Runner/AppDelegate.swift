import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🚀 AppDelegate.application called")
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        print("✅ Application launched with result: \(result)")
        return result
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        print("🔧 Initializing Flutter engine")
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        print("✅ Plugins registered")
    }
}
