import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var nodeJSChannel: FlutterMethodChannel?
    
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
        
        setupNodeJSChannel(with: engineBridge.pluginRegistry)
    }
    
    private func setupNodeJSChannel(with registrar: FlutterPluginRegistry) {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("❌ Cannot get FlutterViewController")
            return
        }
        
        nodeJSChannel = FlutterMethodChannel(
            name: "com.tvbox/nodejs",
            binaryMessenger: controller.binaryMessenger
        )
        
        nodeJSChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startNodeJS":
                print("📱 Received startNodeJS request")
                NodeJSManager.shared().startNodeJSWithScriptPath("index.js") { success in
                    result(success)
                }
                
            case "getNativeServerPort":
                print("📱 Received getNativeServerPort request")
                // 等待服务器启动
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let port = NodeJSManager.shared().getNativeServerPort()
                    result(port)
                }
                
            case "stopNodeJS":
                print("📱 Received stopNodeJS request")
                NodeJSManager.shared().stopNodeJS()
                result(nil)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
