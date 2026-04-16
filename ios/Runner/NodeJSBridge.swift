import Foundation
import NodeMobile

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    private var nodeChannel: NodeChannel?
    private var isRunning = false
    private var messageQueue: [String] = []
    
    private override init() {
        super.init()
    }
    
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        guard !isRunning else {
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
        
        // 等待Node.js初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.isRunning = true
            self.processMessageQueue()
            completion(true)
        }
    }
    
    func stopNodeJS() {
        guard isRunning else { return }
        nodeChannel?.stop()
        isRunning = false
        messageQueue.removeAll()
    }
    
    // 原项目的run动作：加载本地Spider脚本
    func runScript(_ path: String) {
        sendMessage(JSON.stringify([
            "action": "run",
            "path": path
        ]))
    }
    
    // 原项目的nativeServerPort：设置Dart端服务器端口
    func setNativeServerPort(_ port: Int) {
        sendMessage(JSON.stringify([
            "action": "nativeServerPort",
            "port": port
        ]))
    }
    
    func sendMessage(_ message: String) {
        if isRunning {
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
        
        // 处理原项目的CatVod端口事件
        if message == "ready" {
            print("Node.js runtime ready")
            return
        }
        
        // 转发事件到Dart端
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}
