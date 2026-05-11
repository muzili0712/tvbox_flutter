import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var nodeJSChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    fileprivate var eventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as? FlutterViewController
        
        setupNodeJSChannel(with: controller)
        setupEventChannel(with: controller)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupNodeJSChannel(with controller: FlutterViewController?) {
        guard let controller = controller else {
            print("Cannot get FlutterViewController")
            return
        }

        nodeJSChannel = FlutterMethodChannel(
            name: "com.tvbox/nodejs",
            binaryMessenger: controller.binaryMessenger
        )

        nodeJSChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startNodeJS":
                NodeJSManager.shared().startNodeJS { success in
                    result(success)
                }

            case "getNativeServerPort":
                let port = NodeJSManager.shared().getNativeServerPort()
                result(port)

            case "stopNodeJS":
                NodeJSManager.shared().stopNodeJS()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupEventChannel(with controller: FlutterViewController?) {
        guard let controller = controller else {
            print("Cannot get FlutterViewController for event channel")
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
