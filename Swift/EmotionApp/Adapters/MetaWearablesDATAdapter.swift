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
