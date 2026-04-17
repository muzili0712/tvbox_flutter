import Foundation
import NodeMobile

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    
    private var isRunning = false
    private var nodeServerPort: Int?
    private var flutterServerPort: Int = 0
    private var messageHandlers: [String: (Result<Any, Error>) -> Void] = [:]
    private let queue = DispatchQueue(label: "com.tvbox.nodejs")
    
    // 启动 Flutter 端 HTTP 服务（接收来自 Node 的回调）
    private var httpServer: HttpServer?
    
    private override init() {
        super.init()
        startFlutterHttpServer()
    }
    
    // MARK: - Flutter HTTP 服务（模拟 catDartServerPort）
    private func startFlutterHttpServer() {
        httpServer = HttpServer()
        httpServer?.get("/ping") { req in
            return HttpResponse.ok(.text("pong"))
        }
        httpServer?.post("/onCatPawOpenPort") { [weak self] req in
            guard let portStr = req.queryParams.first(where: { $0.0 == "port" })?.1,
                  let port = Int(portStr) else {
                return HttpResponse.badRequest(.text("Missing port"))
            }
            self?.nodeServerPort = port
            print("✅ Node.js service port registered: \(port)")
            return HttpResponse.ok(.text("OK"))
        }
        httpServer?.post("/msg") { [weak self] req in
            guard let body = req.body else {
                return HttpResponse.badRequest(.text("Empty body"))
            }
            // 将 Node 发来的消息转发给 Dart 端
            let message = String(decoding: body, as: UTF8.self)
            self?.handleMessageFromNode(message)
            return HttpResponse.ok(.text("OK"))
        }
        do {
            try httpServer?.start(0) // 自动分配端口
            flutterServerPort = httpServer?.port ?? 0
            print("✅ Flutter HTTP server started on port \(flutterServerPort)")
        } catch {
            print("❌ Failed to start Flutter HTTP server: \(error)")
        }
    }
    
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isRunning else {
                DispatchQueue.main.async { completion(true) }
                return
            }
            
            guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
                print("❌ Node.js script not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 使用 C 函数启动 Node.js
            typealias NodeStartFunc = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
            guard let node_start = self.getSymbol("node_start") as NodeStartFunc? else {
                print("❌ node_start not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let args = ["node", scriptPath]
            var cArgs = args.map { strdup($0) }
            let argc = Int32(cArgs.count)
            
            // 在后台线程启动 Node.js（阻塞式）
            DispatchQueue.global(qos: .userInitiated).async {
                let result = node_start(argc, &cArgs)
                for ptr in cArgs { free(ptr) }
                print("Node.js exited with code: \(result)")
                self.isRunning = false
            }
            
            Thread.sleep(forTimeInterval: 2.0) // 等待 Node 初始化
            self.isRunning = true
            
            // 告知 Node 端 Flutter HTTP 服务端口
            self.sendMessageToNode(action: "nativeServerPort", params: ["port": self.flutterServerPort])
            
            DispatchQueue.main.async { completion(true) }
        }
    }
    
    func stopNodeJS() {
        queue.async { [weak self] in
            self?.httpServer?.stop()
            self?.isRunning = false
        }
    }
    
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 通过 HTTP POST 发送消息到 Node 服务
            guard let nodePort = self.nodeServerPort else {
                completion?(.failure(NSError(domain: "NodeJS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Node service not ready"])))
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
    
    private func sendMessageToNode(action: String, params: [String: Any]) {
        let msg: [String: Any] = ["action": action, "params": params]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: msg),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        sendMessage(jsonString, completion: nil)
    }
    
    private func getSymbol<T>(_ name: String) -> T? {
        let handle = dlopen(nil, RTLD_NOW)
        defer { dlclose(handle) }
        guard let ptr = dlsym(handle, name) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }
    
    private func handleMessageFromNode(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}

// 简单的嵌入式 HTTP 服务器（用于接收 Node 回调）
import Swifter // 需要在 Podfile 中添加
