import Foundation
import AVFoundation
import EmotionCore

/// Microphone-based audio provider for iOS
public class MicrophoneAudioProvider: NSObject, AudioProvider {
    public var onAudioChunk: ((Data) -> Void)?
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    public override init() {
        super.init()
    }
    
    public func start() {
        setupAudioEngine()
        startRecording()
    }
    
    public func stop() {
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
    }
    
    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
            return
        }
        
        // Get the input format
        let inputFormat = input.inputFormat(forBus: 0)
        
        // Define the desired format: 16kHz, mono, 32-bit float PCM
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            print("Failed to create recording format")
            return
        }
        
        // Install tap on input node
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, inputFormat: inputFormat, outputFormat: recordingFormat)
        }
        
        self.audioEngine = engine
        self.inputNode = input
    }
    
    private func startRecording() {
        guard let engine = audioEngine else { return }
        
        do {
            engine.prepare()
            try engine.start()
            print("Audio engine started")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        // Convert buffer format if needed
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("Failed to create audio converter")
            return
        }
        
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            print("Failed to create converted buffer")
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Conversion error: \(error)")
            return
        }
        
        // Convert to Data
        guard let channelData = convertedBuffer.floatChannelData else { return }
        let frameLength = Int(convertedBuffer.frameLength)
        let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)
        
        // Call the audio chunk callback
        DispatchQueue.main.async { [weak self] in
            self?.onAudioChunk?(data)
        }
    }
}
