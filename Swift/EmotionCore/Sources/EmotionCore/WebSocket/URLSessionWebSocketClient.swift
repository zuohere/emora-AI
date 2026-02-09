import Foundation
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "WebSocket")

public class URLSessionWebSocketClient: NSObject, WebSocketClient {
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    
    public var onMessageData: ((Data) -> Void)?
    public var onConnected: (() -> Void)?
    public var onDisconnected: ((Error?) -> Void)?
    
    private var isConnected = false
    private let queue = DispatchQueue(label: "com.emora.websocket", qos: .userInitiated)
    private var retryCount = 0
    private let maxRetries = 5
    
    public override init() {
        super.init()
    }
    
    public func connect(url: URL, token: String?) {
        queue.async { [weak self] in
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            
            self?.session = URLSession(configuration: config)
            guard let session = self?.session else { return }
            
            self?.webSocket = session.webSocketTask(with: request)
            self?.webSocket?.resume()
            
            self?.isConnected = true
            self?.retryCount = 0
            
            DispatchQueue.main.async {
                self?.onConnected?()
            }
            
            os_log("WebSocket连接中: %@", log: log, type: .info, url.absoluteString)
            self?.receiveMessage()
        }
    }
    
    public func send(data: Data) {
        guard isConnected else {
            os_log("WebSocket未连接", log: log, type: .warning)
            return
        }
        
        queue.async { [weak self] in
            let message = URLSessionWebSocketTask.Message.data(data)
            self?.webSocket?.send(message) { error in
                if let error = error {
                    os_log("发送数据失败: %@", log: log, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    public func send(text: String) {
        guard isConnected else {
            os_log("WebSocket未连接", log: log, type: .warning)
            return
        }
        
        queue.async { [weak self] in
            let message = URLSessionWebSocketTask.Message.string(text)
            self?.webSocket?.send(message) { error in
                if let error = error {
                    os_log("发送文本失败: %@", log: log, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    public func disconnect() {
        queue.async { [weak self] in
            self?.isConnected = false
            self?.webSocket?.cancel(with: .goingAway, reason: "客户端关闭".data(using: .utf8))
            
            DispatchQueue.main.async {
                self?.onDisconnected?(nil)
            }
            
            os_log("WebSocket已断开连接", log: log, type: .info)
        }
    }
    
    private func receiveMessage() {
        guard isConnected else { return }
        
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    DispatchQueue.main.async {
                        self?.onMessageData?(data)
                    }
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        DispatchQueue.main.async {
                            self?.onMessageData?(data)
                        }
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()
                
            case .failure(let error):
                os_log("WebSocket接收失败: %@", log: log, type: .error, error.localizedDescription)
                self?.isConnected = false
                
                DispatchQueue.main.async {
                    self?.onDisconnected?(error)
                }
                
                if (self?.retryCount ?? 0) < (self?.maxRetries ?? 5) {
                    self?.retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.receiveMessage()
                    }
                }
            }
        }
    }
    
    deinit {
        disconnect()
    }
}
