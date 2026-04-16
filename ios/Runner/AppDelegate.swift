import UIKit
import Flutter
import NodeMobile

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var nodeChannel: NodeChannel?
    private var isNodeRunning = false
    private var messageQueue: [String] = []
    private var completionHandlers: [String: (Result<Any, Error>) -> Void] = [:]
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let nodeChannel = FlutterMethodChannel(name: "com.tvbox/nodejs", binaryMessenger: controller.binaryMessenger)
        
        nodeChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "sendMessage":
                if let message = call.arguments as? String {
                    self?.sendMessageToNode(message, completion: { res in
                        switch res {
                        case .success(let data):
                            result(data)
                        case .failure(let error):
                            result(FlutterError(code: "NODEJS_ERROR", message: error.localizedDescription, details: nil))
                        }
                    })
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Message must be a string", details: nil))
                }
            case "startNodeJS":
                self?.startNodeJS { success in
                    result(success)
                }
            case "stopNodeJS":
                self?.stopNodeJS()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        stopNodeJS()
    }
    
    // MARK: - NodeJS Bridge
    
    private func startNodeJS(completion: @escaping (Bool) -> Void) {
        guard !isNodeRunning else {
            completion(true)
            return
        }
        
        guard let nodePath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
            print("Node.js script not found")
            completion(false)
            return
        }
        
        let nodeArgs = ["node", nodePath]
        
        nodeChannel = NodeChannel(start: nodeArgs) { [weak self] message in
            self?.handleMessageFromNode(message)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.isNodeRunning = true
            self.processMessageQueue()
            completion(true)
        }
    }
    
    private func stopNodeJS() {
        guard isNodeRunning else { return }
        nodeChannel?.stop()
        isNodeRunning = false
        messageQueue.removeAll()
        completionHandlers.removeAll()
    }
    
    private func sendMessageToNode(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        if let completion = completion {
            let messageId = UUID().uuidString
            completionHandlers[messageId] = completion
            
            if let data = message.data(using: .utf8),
               var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json["messageId"] = messageId
                if let jsonData = try? JSONSerialization.data(withJSONObject: json),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    if isNodeRunning {
                        nodeChannel?.sendMessage(jsonString)
                    } else {
                        messageQueue.append(jsonString)
                    }
                    return
                }
            }
        }
        
        if isNodeRunning {
            nodeChannel?.sendMessage(message)
        } else {
            messageQueue.append(message)
        }
    }
    
    private func processMessageQueue() {
        while !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            nodeChannel?.sendMessage(message)
        }
    }
    
    private func handleMessageFromNode(_ message: String) {
        print("Received from Node.js: \(message)")
        
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messageId = json["messageId"] as? String,
           let completion = completionHandlers[messageId] {
            
            if let error = json["error"] as? String {
                completion(.failure(NSError(domain: "NodeJS", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
            } else {
                completion(.success(json["result"] ?? NSNull()))
            }
            
            completionHandlers.removeValue(forKey: messageId)
            return
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}
