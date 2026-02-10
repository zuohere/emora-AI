import Foundation
import Combine
import AVFoundation
import VideoToolbox
import OSLog

#if canImport(UIKit)
import UIKit
#endif

private let log = OSLog(subsystem: "com.emora.emotion", category: "EmotionCoreManager")

public protocol WebSocketClient {
    func connect(url: URL, token: String?)
    func send(data: Data)
    func send(text: String)
    func disconnect()
    var onMessageData: ((Data) -> Void)? { get set }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: ((Error?) -> Void)? { get set }
}

@available(macOS 10.15, iOS 13.0, *)
@preconcurrency
public class EmotionCoreManager: ObservableObject {
    nonisolated(unsafe) public static let shared = EmotionCoreManager()

    // Providers (在 App 层注入)
    public var videoProvider: VideoProvider?
    public var audioProvider: AudioProvider?
    public var wearablesProvider: WearablesProvider?

    // WebSocket client（注入，便于测试）
    public var wsClient: WebSocketClient?

    // Encoders
    private var videoEncoder: H264Encoder?
    private var audioEncoder: AudioEncoder?

    // Published properties 供 UI 层订阅
    @Published public var emotionResult: String = "等待分析..."
    @Published public var emotionScores: [String: Double] = [:]
    @Published public var dominantEmotion: String = "neutral"
    @Published public var currentFrame: UIImage?

    private var cancellables = Set<AnyCancellable>()

    // Encoder settings
    private let videoWidth = 640
    private let videoHeight = 480
    private let videoFPS: Int32 = 30

    public init() {
        setupEncoders()
    }

    private func setupEncoders() {
        // Initialize H264 encoder
        videoEncoder = H264Encoder(width: videoWidth, height: videoHeight, fps: videoFPS)
        videoEncoder?.onEncodedData = { [weak self] data, isKeyframe in
            self?.sendVideoData(data, isKeyframe: isKeyframe)
        }

        // Initialize Audio encoder (16kHz, mono)
        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: 16000,
                                       channels: 1,
                                       interleaved: false)!
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                        sampleRate: 16000,
                                        channels: 1,
                                        interleaved: false)!
        audioEncoder = AudioEncoder(inputFormat: inputFormat, outputFormat: outputFormat)
        audioEncoder?.onEncodedData = { [weak self] data in
            self?.sendAudioData(data)
        }

        _ = videoEncoder?.start()
    }

    public func configure(wsClient: WebSocketClient, videoProvider: VideoProvider? = nil, audioProvider: AudioProvider? = nil) {
        self.wsClient = wsClient
        self.videoProvider = videoProvider
        self.audioProvider = audioProvider

        #if canImport(UIKit)
        self.videoProvider?.onFrame = { [weak self] image in
            self?.handleFrame(image)
        }
        #else
        self.videoProvider?.onFrame = { [weak self] pixelBuffer in
            self?.handleFrame(pixelBuffer)
        }
        #endif

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
    #if canImport(UIKit)
    public func injectFrame(_ image: UIImage) {
        handleFrame(image)
    }
    #endif

    public func injectFrame(pixelBuffer: CVPixelBuffer) {
        handleFrame(pixelBuffer)
    }

    public func injectAudioChunk(_ data: Data) {
        handleAudioChunk(data)
    }

    // MARK: - internal handlers
    #if canImport(UIKit)
    private func handleFrame(_ image: UIImage) {
        DispatchQueue.main.async {
            nonisolated(unsafe) let unsafeSelf = self
            unsafeSelf.currentFrame = image
        }
        
        // 直接从UIImage转换而不强制调整大小，让编码器处理缩放
        guard let pixelBuffer = image.toCVPixelBuffer() else {
            os_log("Failed to convert UIImage to CVPixelBuffer", log: log, type: .error)
            return
        }
        videoEncoder?.encode(pixelBuffer: pixelBuffer)
    }
    #endif

    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        videoEncoder?.encode(pixelBuffer: pixelBuffer)
    }

    private func handleAudioChunk(_ data: Data) {
        guard data.count > 0 else { return }

        let frameCount = AVAudioFrameCount(data.count / 4) // Float32 = 4 bytes per sample
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16000,
                                         channels: 1,
                                         interleaved: false) else {
            return
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddr = ptr.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            memcpy(channelData, baseAddr, data.count)
        }

        audioEncoder?.encode(buffer)
    }

    private func handleServerMessage(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                nonisolated(unsafe) let unsafeSelf = self
                if let emotionResult = json["emotion_result"] as? String {
                    DispatchQueue.main.async {
                        unsafeSelf.emotionResult = emotionResult
                    }
                }

                if let scores = json["emotion_scores"] as? [String: Double] {
                    DispatchQueue.main.async {
                        unsafeSelf.emotionScores = scores
                    }

                    // Find dominant emotion
                    if let dominant = scores.max(by: { $0.value < $1.value }) {
                        DispatchQueue.main.async {
                            unsafeSelf.dominantEmotion = dominant.key
                        }
                    }
                }

                os_log("Received emotion result: %@", log: log, type: .debug, json.debugDescription)
            }
        } catch {
            os_log("Failed to parse server message: %@", log: log, type: .error, error.localizedDescription)
        }
    }

    // MARK: - send helpers
    private func sendVideoData(_ data: Data, isKeyframe: Bool) {
        let payload: [String: Any] = [
            "type": "video_frame",
            "is_keyframe": isKeyframe,
            "data": data.base64EncodedString()
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            os_log("发送视频数据: %d bytes (keyframe: %{public}@)", log: log, type: .debug, data.count, isKeyframe ? "true" : "false")
            wsClient?.send(data: jsonData)
        } catch {
            os_log("Failed to serialize video data: %@", log: log, type: .error, error.localizedDescription)
        }
    }

    private func sendAudioData(_ data: Data) {
        let payload: [String: Any] = [
            "type": "audio_chunk",
            "data": data.base64EncodedString()
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            os_log("发送音频数据: %d bytes", log: log, type: .debug, data.count)
            wsClient?.send(data: jsonData)
        } catch {
            os_log("Failed to serialize audio data: %@", log: log, type: .error, error.localizedDescription)
        }
    }

    deinit {
        videoEncoder?.stop()
    }
}

// MARK: - UIImage Extension
#if canImport(UIKit)
extension UIImage {
    // 无参数版本 - 保持原始尺寸
    func toCVPixelBuffer() -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else { return nil }
        return toCVPixelBuffer(width: cgImage.width, height: cgImage.height)
    }
    
    // 有参数版本 - 调整到指定尺寸
    func toCVPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context.draw(cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}
#endif
