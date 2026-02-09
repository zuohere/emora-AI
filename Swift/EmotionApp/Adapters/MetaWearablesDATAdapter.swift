import Foundation
import UIKit

// Adapter skeleton to be implemented in the App target using the Meta Wearables iOS SDK
class MetaWearablesDATAdapter: VideoProvider, AudioProvider {
    var onFrame: ((UIImage) -> Void)?
    var onAudioChunk: ((Data) -> Void)?

    func start() {
        // Initialize Meta SDK, register callbacks
    }

    func stop() {
        // Unregister callbacks and cleanup
    }

    // Example SDK callbacks (pseudocode):
    // func sdkDidReceiveFrame(_ pixelBuffer: CVPixelBuffer) { onFrame?(UIImage(pixelBuffer: pixelBuffer)) }
    // func sdkDidReceiveAudio(_ data: Data) { onAudioChunk?(data) }
}
