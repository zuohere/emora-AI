import Foundation
import AVFoundation
import UIKit
import EmotionCore

/// Camera-based video provider for iOS
public class CameraVideoProvider: NSObject, VideoProvider {
    public var onFrame: ((UIImage) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.emora.emotion.camera")
    
    public override init() {
        super.init()
    }
    
    public func start() {
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    
    public func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Configure session preset
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .medium
        }
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("Failed to setup camera input")
            return
        }
        session.addInput(input)
        
        // Add video output
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
        
        session.commitConfiguration()
        
        self.captureSession = session
        session.startRunning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraVideoProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert CVPixelBuffer to UIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        // Call the frame callback on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(image)
        }
    }
}
