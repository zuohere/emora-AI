import SwiftUI
import EmotionCore

@main
struct EmotionAppApp: App {
    @StateObject private var manager = EmotionCoreManager.shared
    
    init() {
        // 创建并配置依赖
        let wsClient = URLSessionWebSocketClient()
        let videoProvider = CameraVideoProvider()
        let audioProvider = MicrophoneAudioProvider()
        
        // 配置 EmotionCoreManager
        EmotionCoreManager.shared.configure(
            wsClient: wsClient,
            videoProvider: videoProvider,
            audioProvider: audioProvider
        )
        
        // 可选：连接到 WebSocket 服务器
        // wsClient.connect(url: URL(string: "wss://your-server.com/ws")!, token: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }
    }
}
