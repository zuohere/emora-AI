import Foundation
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

public protocol VideoProvider: AnyObject {
    #if canImport(UIKit)
    var onFrame: ((UIImage) -> Void)? { get set }
    #else
    var onFrame: ((CVPixelBuffer) -> Void)? { get set }
    #endif
    func start()
    func stop()
}

public protocol AudioProvider: AnyObject {
    var onAudioChunk: ((Data) -> Void)? { get set } // 原始 PCM 或 AAC chunk
    func start()
    func stop()
}

public protocol WearablesProvider: AnyObject {
    var onVital: (([String: Any]) -> Void)? { get set }
    func start()
    func stop()
}
