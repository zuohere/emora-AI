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
