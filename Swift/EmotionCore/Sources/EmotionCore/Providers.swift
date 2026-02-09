import Foundation
import UIKit
import AVFoundation

public protocol VideoProvider: AnyObject {
    var onFrame: ((UIImage) -> Void)? { get set }
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
