import SwiftUI
import UIKit
import EmotionCore

/// SwiftUI wrapper for displaying live camera preview
public struct CameraPreview: View {
    @ObservedObject var manager: EmotionCoreManager
    
    public init(manager: EmotionCoreManager = .shared) {
        self.manager = manager
    }
    
    public var body: some View {
        ZStack {
            // 背景
            Color.black
            
            // 摄像头预览图像
            if let image = manager.currentFrame {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                VStack {
                    ProgressView()
                    Text("等待摄像头...")
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                }
            }
        }
        .cornerRadius(12)
        .clipped()
    }
}

#Preview {
    CameraPreview(manager: EmotionCoreManager.shared)
        .frame(height: 300)
        .padding()
}

