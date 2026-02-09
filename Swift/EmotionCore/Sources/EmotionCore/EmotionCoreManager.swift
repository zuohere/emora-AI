import Foundation
import Combine
import UIKit

public protocol WebSocketClient {
    func connect(url: URL, token: String?)
    func send(data: Data)
    func send(text: String)
    func disconnect()
    var onMessageData: ((Data) -> Void)? { get set }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: ((Error?) -> Void)? { get set }
}

public class EmotionCoreManager: ObservableObject {
    public static let shared = EmotionCoreManager()

    // Providers (在 App 层注入)
    public var videoProvider: VideoProvider?
    public var audioProvider: AudioProvider?
    public var wearablesProvider: WearablesProvider?

    // WebSocket client（注入，便于测试）
    public var wsClient: WebSocketClient?

    // Published properties 供 UI 层订阅
    @Published public var emotionResult: String = "等待分析..."
    @Published public var emotionScores: [String: Double] = [:]
    @Published public var dominantEmotion: String = "neutral"

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func configure(wsClient: WebSocketClient, videoProvider: VideoProvider? = nil, audioProvider: AudioProvider? = nil) {
        self.wsClient = wsClient
        self.videoProvider = videoProvider
        self.audioProvider = audioProvider

        self.videoProvider?.onFrame = { [weak self] image in
            self?.handleFrame(image)
        }
        self.audioProvider?.onAudioChunk = { [weak self] data in
            self?.handleAudioChunk(data)
        }

        self.wsClient?.onMessageData = { [weak self] data in
            self?.handleServerMessage(data)
        }
    }

    public func start() {
        videoProvider?.start()
        audioProvider?.start()
        wearablesProvider?.start()
    }

    public func stop() {
        videoProvider?.stop()
        audioProvider?.stop()
        wearablesProvider?.stop()
    }

    // MARK: - inject helpers for debug
    public func injectFrame(_ image: UIImage) {
        // 编码并发送或本地推理
    }

    public func injectAudioChunk(_ data: Data) {
        // 发送音频片段
    }

    // MARK: - internal handlers
    private func handleFrame(_ image: UIImage) {
        // 编码 & 发送给后端，或本地模型推理
    }

    private func handleAudioChunk(_ data: Data) {
        // 送 audio encoder / ws
    }

    private func handleServerMessage(_ data: Data) {
        // 解析 emotion_result 等
        // 更新 Published 属性
    }
}
