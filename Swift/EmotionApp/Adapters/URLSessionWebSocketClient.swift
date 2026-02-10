import Foundation
import EmotionCore
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "WebSocketClient")

/// URLSession-based WebSocket client implementation
public class URLSessionWebSocketClient: NSObject, WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    public var onMessageData: ((Data) -> Void)?
    public var onConnected: (() -> Void)?
    public var onDisconnected: ((Error?) -> Void)?
    
    private var isConnected = false
    private let connectionLock = NSLock()
    
    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    public func connect(url: URL, token: String?) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        os_log("开始连接WebSocket: %{public}@", log: log, type: .info, url.absoluteString)
        
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage()
        // 注意：onConnected 将在 urlSession(_:webSocketTask:didOpenWithProtocol:) delegate 方法中调用
    }
    
    public func send(data: Data) {
        connectionLock.lock()
        let connected = isConnected
        let task = webSocketTask
        connectionLock.unlock()
        
        guard connected, let task = task else {
            os_log("❌ WebSocket未连接，无法发送数据 (isConnected: %{public}@)", log: log, type: .error, connected ? "true" : "false")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        task.send(message) { error in
            if let error = error {
                os_log("❌ WebSocket发送错误: %{public}@", log: log, type: .error, error.localizedDescription)
            } else {
                os_log("✅ WebSocket数据已发送: %d bytes", log: log, type: .debug, data.count)
            }
        }
    }
    
    public func send(text: String) {
        connectionLock.lock()
        let connected = isConnected
        let task = webSocketTask
        connectionLock.unlock()
        
        guard connected, let task = task else {
            os_log("❌ WebSocket未连接，无法发送文本", log: log, type: .error)
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        task.send(message) { error in
            if let error = error {
                os_log("❌ WebSocket发送文本错误: %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
    }
    
    public func disconnect() {
        connectionLock.lock()
        isConnected = false
        connectionLock.unlock()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        os_log("WebSocket已断开连接", log: log, type: .info)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    os_log("📥 收到WebSocket数据: %d bytes", log: log, type: .debug, data.count)
                    self.onMessageData?(data)
                case .string(let text):
                    os_log("📥 收到WebSocket文本: %{public}@", log: log, type: .debug, text)
                    if let data = text.data(using: .utf8) {
                        self.onMessageData?(data)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                os_log("❌ WebSocket接收错误: %{public}@", log: log, type: .error, error.localizedDescription)
                self.connectionLock.lock()
                self.isConnected = false
                self.connectionLock.unlock()
                self.onDisconnected?(error)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension URLSessionWebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolString: String?) {
        os_log("✅ WebSocket已连接 (protocol: %{public}@)", log: log, type: .info, protocolString ?? "none")
        connectionLock.lock()
        isConnected = true
        connectionLock.unlock()
        onConnected?()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        os_log("⚠️ WebSocket已关闭 (closeCode: %{public}@)", log: log, type: .info, "\(closeCode.rawValue)")
        connectionLock.lock()
        isConnected = false
        connectionLock.unlock()
        onDisconnected?(nil)
    }
}

