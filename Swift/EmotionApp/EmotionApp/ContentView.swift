import SwiftUI
import EmotionCore
import EmotionUI

struct ContentView: View {
    @EnvironmentObject var manager: EmotionCoreManager
    @State private var isCapturing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 情绪分析视图
                EmotionAnalysisView()
                
                Spacer()
                
                // 控制按钮
                HStack(spacing: 20) {
                    Button(action: toggleCapture) {
                        Label(
                            isCapturing ? "停止采集" : "开始采集",
                            systemImage: isCapturing ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isCapturing ? Color.red : Color.green)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // 状态信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(isCapturing ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                        Text(isCapturing ? "采集中" : "已停止")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Emotion Analysis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func toggleCapture() {
        isCapturing.toggle()
        
        if isCapturing {
            manager.videoProvider?.start()
            manager.audioProvider?.start()
        } else {
            manager.videoProvider?.stop()
            manager.audioProvider?.stop()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EmotionCoreManager.shared)
}
