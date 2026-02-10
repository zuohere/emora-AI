import SwiftUI
import EmotionCore
import OSLog

private let log = OSLog(subsystem: "com.emora.emotion", category: "App")

@main
struct EmotionAppApp: App {
    @StateObject private var manager = EmotionCoreManager.shared

    init() {
        // 创建并配置依赖 - 使用 Meta Wearables 适配器
        let wsClient = URLSessionWebSocketClient()
        let metaAdapter = MetaWearablesDATAdapter()

        // 配置 EmotionCoreManager
        EmotionCoreManager.shared.configure(
            wsClient: wsClient,
            videoProvider: metaAdapter,
            audioProvider: metaAdapter
        )

        // 设置连接状态回调
        wsClient.onConnected = {
            os_log("✅ WebSocket 连接成功", log: log, type: .info)
            // WebSocket 连接成功后，启动数据采集
            metaAdapter.start()
            
            // 发送测试消息以验证连接
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let testMessage = "{\"type\":\"test\",\"message\":\"App connected\"}"
                wsClient.send(text: testMessage)
                os_log("📤 发送测试消息", log: log, type: .info)
            }
        }

        wsClient.onDisconnected = { error in
            if let error = error {
                os_log("❌ WebSocket 断开: %{public}@", log: log, type: .error, error.localizedDescription)
            } else {
                os_log("⚠️ WebSocket 断开连接", log: log, type: .info)
            }
            // WebSocket 断开时，停止数据采集
            metaAdapter.stop()
        }

        // 连接到 WebSocket 服务器
        // ⚠️ 配置说明: 请修改此处的 WebSocket URL 为实际服务器地址
        let wsUrlString = "ws://10.10.40.54:8900/ws"
        os_log("正在连接到 WebSocket 服务器: %{public}@", log: log, type: .info, wsUrlString)

        if let wsUrl = URL(string: wsUrlString) {
            wsClient.connect(url: wsUrl, token: nil)
        } else {
            os_log("❌ WebSocket URL 格式无效: %{public}@", log: log, type: .error, wsUrlString)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }
    }
}
