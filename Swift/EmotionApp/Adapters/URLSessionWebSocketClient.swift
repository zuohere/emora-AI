import Foundation
import EmotionCore

/// URLSession-based WebSocket client implementation
public class URLSessionWebSocketClient: NSObject, WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    public var onMessageData: ((Data) -> Void)?
    public var onConnected: (() -> Void)?
    public var onDisconnected: ((Error?) -> Void)?
    
    private var isConnected = false
    
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
        
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage()
        
        isConnected = true
        onConnected?()
    }
    
    public func send(data: Data) {
        guard isConnected else { return }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    public func send(text: String) {
        guard isConnected else { return }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    public func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.onMessageData?(data)
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.onMessageData?(data)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.isConnected = false
                self.onDisconnected?(error)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension URLSessionWebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        isConnected = true
        onConnected?()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected with code: \(closeCode)")
        isConnected = false
        onDisconnected?(nil)
    }
}
