import Foundation
import GCDWebServer

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    
    private var isRunning = false
    private var nodeServerPort: Int?
    private let webServer = GCDWebServer()
    private let queue = DispatchQueue(label: "com.tvbox.nodejs")
    private var serverStarted = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - HTTP Server
    private func ensureWebServerStarted(completion: @escaping (Bool) -> Void) {
        if serverStarted {
            completion(true)
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            self.webServer.removeAllHandlers()
            
            self.webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request in
                if request.path == "/onCatPawOpenPort" {
                    if let portStr = request.query?["port"], let port = Int(portStr) {
                        self?.nodeServerPort = port
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
            
            let exception = self.catchException {
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
            
            if let exception = exception {
                print("❌ HTTP server exception: \(exception)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // MARK: - Node.js Startup
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        ensureWebServerStarted { [weak self] success in
            guard let self = self else {
                completion(false)
                return
            }
            if !success {
                print("❌ Web server failed to start, aborting Node.js launch")
                completion(false)
                return
            }
            
            self.queue.async {
                if self.isRunning {
                    DispatchQueue.main.async { completion(true) }
                    return
                }
                
                guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
                    print("❌ Node.js script not found")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                let args = ["node", scriptPath]
                var cArgs = args.map { strdup($0) }
                let argc = Int32(cArgs.count)
                
                DispatchQueue.global(qos: .userInitiated).async {
                    // 直接调用 C 函数
                    _ = node_start(argc, &cArgs)
                    for ptr in cArgs { free(ptr) }
                    self.isRunning = false
                    print("Node.js exited")
                }
                
                Thread.sleep(forTimeInterval: 2.0)
                self.isRunning = true
                DispatchQueue.main.async { completion(true) }
            }
        }
    }
    
    func stopNodeJS() {
        queue.async { [weak self] in
            self?.webServer.stop()
            self?.serverStarted = false
            self?.isRunning = false
        }
    }
    
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let nodePort = self?.nodeServerPort else {
                completion?(.failure(NSError(domain: "NodeJS", code: -1,
                                             userInfo: [NSLocalizedDescriptionKey: "Node service port unknown"])))
                return
            }
            
            let url = URL(string: "http://127.0.0.1:\(nodePort)/msg")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = message.data(using: .utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            URLSession.shared.dataTask(with: request) { _, _, error in
                if let error = error {
                    completion?(.failure(error))
                } else {
                    completion?(.success(NSNull()))
                }
            }.resume()
        }
    }
    
    private func handleMessageFromNode(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    private func catchException(_ block: @escaping () -> Void) -> NSException? {
        var result: NSException?
        let exceptionHandler = { (exception: NSException) in
            result = exception
        }
        let previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(exceptionHandler)
        block()
        NSSetUncaughtExceptionHandler(previousHandler)
        return result
    }
}
