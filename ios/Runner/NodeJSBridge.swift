import Foundation
import GCDWebServer

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    
    private let webServer = GCDWebServer()
    private let queue = DispatchQueue(label: "com.tvbox.nodejs")
    private var serverStarted = false
    private let nodeManager = NodeJSManager.shared()
    
    private override init() {
        super.init()
    }
    
    private func ensureWebServerStarted(completion: @escaping (Bool) -> Void) {
        if serverStarted {
            completion(true)
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.webServer.removeAllHandlers()
            
            self.webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request in
                if request.path == "/onCatPawOpenPort" {
                    if let portStr = request.query?["port"], let port = Int(portStr) {
                        self?.nodeManager.setNodeServerPort(Int32(port))
                        print("🐱 Node.js source server port: \(port)")
                    }
                    return GCDWebServerDataResponse(text: "OK")
                }
                return GCDWebServerResponse(statusCode: 404)
            }
            
            self.webServer.addHandler(forMethod: "POST", path: "/msg", request: GCDWebServerDataRequest.self) { [weak self] request in
                if let dataRequest = request as? GCDWebServerDataRequest {
                    let body = String(data: dataRequest.data, encoding: .utf8) ?? ""
                    self?.handleMessageFromNode(body)
                }
                return GCDWebServerDataResponse(text: "OK")
            }
            
            // 直接启动服务器,使用 do-catch 处理错误
            do {
                try self.webServer.start(options: [
                    GCDWebServerOption_Port: 0,
                    GCDWebServerOption_BindToLocalhost: true,
                    GCDWebServerOption_AutomaticallySuspendInBackground: false
                ])
                self.serverStarted = true
                let port = self.webServer.port
                setenv("DART_SERVER_PORT", "\(port)", 1)
                print("✅ HTTP server started on port \(port)")
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("❌ HTTP server start error: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        ensureWebServerStarted { [weak self] success in
            guard let self = self else { return }
            if !success {
                completion(false)
                return
            }
            
            guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
                print("❌ Node.js script not found")
                completion(false)
                return
            }
            
            self.nodeManager.startNodeJS(withScriptPath: scriptPath) { success in
                completion(success)
            }
        }
    }
    
    func stopNodeJS() {
        queue.async { [weak self] in
            self?.webServer.stop()
            self?.serverStarted = false
            self?.nodeManager.stopNodeJS()
        }
    }
    
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        nodeManager.sendMessage(message) { result, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(result ?? NSNull()))
            }
        }
    }
    
    private func handleMessageFromNode(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}
