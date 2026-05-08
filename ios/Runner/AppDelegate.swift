import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 设置 Node.js 数据库路径为 Documents 目录
        let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        setenv("NODE_PATH", docsPath, 1)
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let nodeChannel = FlutterMethodChannel(name: "com.tvbox/nodejs", binaryMessenger: controller.binaryMessenger)
        
        nodeChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "sendMessage" {
                if let message = call.arguments as? String {
                    NodeJSBridge.shared.sendMessage(message) { res in
                        switch res {
                        case .success(let data):
                            result(data)
                        case .failure(let error):
                            result(FlutterError(code: "NODEJS_ERROR", message: error.localizedDescription, details: nil))
                        }
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Message must be a string", details: nil))
                }
            } else if call.method == "startNodeJS" {
                NodeJSBridge.shared.startNodeJS { success in
                    result(success)
                }
            } else if call.method == "stopNodeJS" {
                NodeJSBridge.shared.stopNodeJS()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        NodeJSBridge.shared.stopNodeJS()
    }
}
