import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var nodeJSChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    fileprivate var eventSink: FlutterEventSink?
    
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
        setupEventChannel(with: engineBridge.pluginRegistry)
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
                NodeJSManager.shared().startNodeJS { success in
                    result(success)
                }
                
            case "getNativeServerPort":
                print("📱 Received getNativeServerPort request")
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
    
    private func setupEventChannel(with registrar: FlutterPluginRegistry) {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("❌ Cannot get FlutterViewController for event channel")
            return
        }
        
        eventChannel = FlutterEventChannel(
            name: "com.tvbox/nodejs/events",
            binaryMessenger: controller.binaryMessenger
        )
        
        eventChannel?.setStreamHandler(NodeEventStreamHandler.shared)
        NodeEventStreamHandler.shared.setAppDelegate(self)
    }
    
    func onNodePortReceived(_ port: Int) {
        print("📡 Notifying Flutter: Node.js port = \(port)")
        eventSink?(port)
    }
}

class NodeEventStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = NodeEventStreamHandler()
    private weak var appDelegate: AppDelegate?
    
    func setAppDelegate(_ delegate: AppDelegate) {
        self.appDelegate = delegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNodePortNotification(_:)),
            name: NSNotification.Name("NodeServerPortReceived"),
            object: nil
        )
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.eventSink = nil
        return nil
    }
    
    @objc private func handleNodePortNotification(_ notification: Notification) {
        if let port = notification.userInfo?["port"] as? Int {
            appDelegate?.onNodePortReceived(port)
        }
    }
}
