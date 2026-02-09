#!/bin/bash

# 创建目录结构
mkdir -p Swift/EmotionCore/Sources/EmotionCore/Encoders
mkdir -p Swift/EmotionCore/Sources/EmotionCore/WebSocket
mkdir -p Swift/EmotionApp/Adapters

# 创建 H264Encoder.swift
cat > Swift/EmotionCore/Sources/EmotionCore/Encoders/H264Encoder.swift << 'EOF'
import AVFoundation
import VideoToolbox
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "H264Encoder")

public class H264Encoder {
    private var compressionSession: VTCompressionSession?
    private var isConfigured = false
    
    private let width: Int
    private let height: Int
    private let fps: Int32
    private var frameCounter: Int = 0
    
    public var onEncodedData: ((Data, Bool) -> Void)?
    
    public init(width: Int, height: Int, fps: Int32 = 30) {
        self.width = width
        self.height = height
        self.fps = fps
    }
    
    public func start() -> Bool {
        guard !isConfigured else { return true }
        
        var error: OSStatus = noErr
        
        let encodingCallback: VTCompressionOutputCallback = { [weak self] (
            encoder,
            sourceFrameRefcon,
            status,
            infoFlags,
            sampleBuffer
        ) in
            guard status == noErr, let sampleBuffer = sampleBuffer else {
                return
            }
            
            if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(dataBuffer)
                var rawData: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &rawData)
                
                if let data = rawData {
                    let encodedData = Data(bytes: data, count: length)
                    let isKeyframe = !CFDictionaryContainsKey(
                        unsafeBitCast(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)[0], to: CFDictionary.self),
                        unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self)
                    )
                    self?.onEncodedData?(encodedData, isKeyframe)
                }
            }
        }
        
        error = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            sourceImageBufferAttributes: nil,
            compressedDataAllocator: kCFAllocatorDefault,
            outputCallback: encodingCallback,
            refcon: nil,
            compressionSessionOut: &compressionSession
        )
        
        guard error == noErr, let session = compressionSession else {
            os_log("创建H264编码会话失败: %d", log: log, type: .error, error)
            return false
        }
        
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_4_0)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: fps))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: Int(fps) * 2))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitrate, value: NSNumber(value: 500000))
        
        isConfigured = true
        os_log("H264编码器已初始化: %dx%d @ %d fps", log: log, type: .info, width, height, fps)
        return true
    }
    
    public func encode(pixelBuffer: CVPixelBuffer) {
        guard let session = compressionSession else { return }
        
        frameCounter += 1
        
        let presentationTimeStamp = CMTime(
            value: Int64(frameCounter),
            timescale: fps
        )
        
        let duration = CMTime(value: 1, timescale: fps)
        
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        
        if status != noErr {
            os_log("H264编码失败: %d", log: log, type: .error, status)
        }
    }
    
    public func flush() {
        guard let session = compressionSession else { return }
        VTCompressionSessionCompleteFrames(session, upToFrameNumber: Int32(frameCounter))
    }
    
    public func stop() {
        guard let session = compressionSession else { return }
        flush()
        VTCompressionSessionInvalidate(session)
        compressionSession = nil
        isConfigured = false
        frameCounter = 0
        os_log("H264编码器已停止", log: log, type: .info)
    }
    
    deinit {
        stop()
    }
}
EOF

# 创建 AudioEncoder.swift
cat > Swift/EmotionCore/Sources/EmotionCore/Encoders/AudioEncoder.swift << 'EOF'
import AVFoundation
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "AudioEncoder")

public class AudioEncoder {
    private var converter: AVAudioConverter?
    private var sampleCounter: Int = 0
    
    public var onEncodedData: ((Data) -> Void)?
    
    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat
    
    public init?(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            os_log("无法创建音频转换器", log: log, type: .error)
            return nil
        }
        
        self.converter = converter
        os_log("AAC编码器已初始化", log: log, type: .info)
    }
    
    public func encode(_ buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }
        
        let outputCapacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * Double(outputFormat.sampleRate) / Double(inputFormat.sampleRate))
        )
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            os_log("无法创建输出缓冲区", log: log, type: .error)
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _ in
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            os_log("音频转换失败: %@", log: log, type: .error, error.localizedDescription)
            return
        }
        
        if let data = audioBufferToData(outputBuffer) {
            onEncodedData?(data)
        }
    }
    
    private func audioBufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let mData = audioBuffer.mData else { return nil }
        
        let dataLength = Int(audioBuffer.mDataByteSize)
        let rawData = Data(bytes: mData, count: dataLength)
        
        let adtsHeader = buildADTSHeader(frameLength: dataLength + 7)
        return adtsHeader + rawData
    }
    
    private func buildADTSHeader(frameLength: Int) -> Data {
        var header = Data(capacity: 7)
        
        let profileObjectType: UInt8 = 2
        let sampleFrequencyIndex: UInt8 = 6
        let channelConfiguration: UInt8 = 1
        
        header.append((0xFF))
        header.append((0xF0) | ((profileObjectType - 1) << 6))
        header.append(((sampleFrequencyIndex << 2) | ((channelConfiguration >> 2) & 0x01)))
        header.append((((channelConfiguration & 0x03) << 6) | ((frameLength >> 11) & 0x03)))
        header.append(UInt8((frameLength >> 3) & 0xFF))
        header.append((((frameLength & 0x07) << 5) | 0x1F))
        header.append(0xFC)
        
        return header
    }
}
EOF

# 创建 URLSessionWebSocketClient.swift
cat > Swift/EmotionCore/Sources/EmotionCore/WebSocket/URLSessionWebSocketClient.swift << 'EOF'
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
EOF

# 创建 MetaWearablesDATAdapter.swift
cat > Swift/EmotionApp/Adapters/MetaWearablesDATAdapter.swift << 'EOF'
import Foundation
import AVFoundation
import UIKit
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "MetaAdapter")

public class MetaWearablesDATAdapter: NSObject, VideoProvider, AudioProvider, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public var onFrame: ((UIImage) -> Void)?
    public var onAudioChunk: ((Data) -> Void)?
    
    private var audioEngine: AVAudioEngine?
    private var isRunning = false
    private var captureSession: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "com.emora.capture")
    
    public override init() {
        super.init()
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        
        setupAudioEngine()
        setupVideoCapture()
        
        os_log("Meta适配器已启动", log: log, type: .info)
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        
        stopAudioEngine()
        stopVideoCapture()
        
        os_log("Meta适配器已停止", log: log, type: .info)
    }
    
    private func setupAudioEngine() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            os_log("音频会话配置失败: %@", log: log, type: .error, error.localizedDescription)
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0) ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try engine.start()
            os_log("音频引擎已启动", log: log, type: .info)
        } catch {
            os_log("音频引擎启动失败: %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    private func stopAudioEngine() {
        guard let engine = audioEngine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioEngine = nil
        os_log("音频引擎已停止", log: log, type: .info)
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }
        
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let data = audioBuffer.mData else { return }
        
        let audioData = Data(bytes: data, count: Int(audioBuffer.mDataByteSize))
        onAudioChunk?(audioData)
    }
    
    private func setupVideoCapture() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        
        session.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            os_log("无法获取摄像头设备", log: log, type: .error)
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            session.startRunning()
            os_log("视频捕获已启动", log: log, type: .info)
            
        } catch {
            os_log("视频捕获设置失败: %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    private func stopVideoCapture() {
        guard let session = captureSession else { return }
        
        if session.isRunning {
            session.stopRunning()
        }
        
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        captureSession = nil
        os_log("视频捕获已停止", log: log, type: .info)
    }
    
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isRunning,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let image = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.onFrame?(image)
            }
        }
    }
}
EOF

echo "✅ 所有文件已创建！"
git add .
git commit -m "feat: Add H264Encoder, AudioEncoder, WebSocketClient, and MetaWearablesDATAdapter"
git push origin main

echo "🎉 代码已提交到GitHub！"