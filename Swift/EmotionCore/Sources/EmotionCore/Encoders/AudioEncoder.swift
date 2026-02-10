@preconcurrency import AVFoundation
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "AudioEncoder")

@preconcurrency public class AudioEncoder {
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
        nonisolated(unsafe) var inputBlockCalled = false
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if inputBlockCalled {
                status.pointee = .noDataNow
                return nil
            }
            inputBlockCalled = true
            status.pointee = .haveData
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

        header.append(0xFF)
        header.append((0xF0) | ((profileObjectType - 1) << 6))
        header.append(((sampleFrequencyIndex << 2) | ((channelConfiguration >> 2) & 0x01)))
        header.append(UInt8((channelConfiguration & 0x03) << 6) | UInt8((frameLength >> 11) & 0x03))
        header.append(UInt8((frameLength >> 3) & 0xFF))
        header.append(UInt8(((frameLength & 0x07) << 5) | 0x1F))
        header.append(0xFC)

        return header
    }
}
