# EmotionApp 快速使用指南

## 概述
EmotionApp 是一个 iOS 应用，集成了 WebSocket 客户端和 Meta Wearables 适配器，用于实时情绪分析。

## 当前实现的功能

### 1. WebSocket 客户端 (URLSessionWebSocketClient)
- **位置**: `Swift/EmotionApp/Adapters/URLSessionWebSocketClient.swift`
- **功能**:
  - 使用 URLSession 建立 WebSocket 连接
  - 支持二进制数据和文本消息
  - 自动接收消息循环
  - 连接状态回调 (onConnected, onDisconnected)
  - 发送数据方法 (send(data:), send(text:))

### 2. Meta Wearables 适配器 (MetaWearablesDATAdapter)
- **位置**: `Swift/EmotionApp/Adapters/MetaWearablesDATAdapter.swift`
- **功能**:
  - 同时实现 `VideoProvider` 和 `AudioProvider` 协议
  - 使用 iPhone 摄像头捕获视频
  - 使用 iPhone 麦克风捕获音频
  - 实时视频帧回调 (onFrame)
  - 实时音频块回调 (onAudioChunk)

### 3. App 配置
- **位置**: `Swift/EmotionApp/EmotionApp/EmotionAppApp.swift`
- **已配置的组件**:
  ```swift
  let wsClient = URLSessionWebSocketClient()
  let metaAdapter = MetaWearablesDATAdapter()

  EmotionCoreManager.shared.configure(
      wsClient: wsClient,
      videoProvider: metaAdapter,
      audioProvider: metaAdapter
  )

  // 自动连接 WebSocket 服务器
  if let wsUrl = URL(string: "wss://your-emotion-server.com/ws") {
      wsClient.connect(url: wsUrl, token: nil)
  }
  ```

## 如何使用

### 1. 配置 WebSocket 服务器地址

打开 `Swift/EmotionApp/EmotionApp/EmotionAppApp.swift`，找到以下代码：

```swift
if let wsUrl = URL(string: "wss://your-emotion-server.com/ws") {
    wsClient.connect(url: wsUrl, token: nil)
}
```

修改为你的实际 WebSocket 服务器地址：

```swift
if let wsUrl = URL(string: "wss://your-actual-server.com/emotion-analysis") {
    wsClient.connect(url: wsUrl, token: "your-auth-token") // 可选: 添加认证 token
}
```

### 2. 构建和运行

1. 打开项目: `Swift/EmotionApp/EmotionApp.xcodeproj`
2. 选择目标设备 (真机或模拟器)
3. 按 Cmd+R 运行

**注意**: 如果使用真机，需要：
- 配置开发者账号
- 设置 Bundle Identifier
- 在设备上信任开发者证书

### 3. 测试流程

1. **启动应用**: 应用启动时会自动连接 WebSocket 服务器
2. **检查连接状态**: 查看 Xcode 控制台的日志输出
   ```
   WebSocket connected
   Meta适配器已启动
   音频引擎已启动
   视频捕获已启动
   ```
3. **开始采集**: 点击界面上的"开始采集"按钮
4. **查看结果**: 情绪分析结果会显示在界面上

### 4. 数据流说明

```
摄像头 → MetaWearablesDATAdapter → EmotionCoreManager → H264Encoder → WebSocketClient → 服务器
麦克风 → MetaWearablesDATAdapter → EmotionCoreManager → AudioEncoder → WebSocketClient → 服务器
服务器响应 → WebSocketClient → EmotionCoreManager → UI 更新
```

## 修改和扩展

### 修改视频分辨率

在 `Swift/EmotionCore/Sources/EmotionCore/EmotionCoreManager.swift` 中：

```swift
private let videoWidth = 640  // 修改宽度
private let videoHeight = 480 // 修改高度
```

### 修改音频采样率

在 `Swift/EmotionCore/Sources/EmotionCore/EmotionCoreManager.swift` 中：

```swift
let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                               sampleRate: 16000,  // 修改采样率
                               channels: 1,
                               interleaved: false)!
```

### 添加认证

在 `Swift/EmotionApp/EmotionApp/EmotionAppApp.swift` 中添加 token：

```swift
wsClient.connect(url: wsUrl, token: "your-bearer-token")
```

### 监听连接状态

在 `ContentView.swift` 中添加：

```swift
.onAppear {
    manager.wsClient?.onConnected = {
        print("✅ WebSocket 连接成功")
    }

    manager.wsClient?.onDisconnected = { error in
        print("❌ WebSocket 断开连接: \(error?.localizedDescription ?? "Unknown")")
    }
}
```

## 常见问题

### Q: 连接失败怎么办？
A: 检查以下几点：
1. WebSocket URL 是否正确
2. 网络是否可用
3. 服务器是否运行
4. 查看 Xcode 控制台的错误日志

### Q: 视频/音频没有数据？
A: 检查以下几点：
1. 是否点击了"开始采集"按钮
2. 权限是否已授予 (相机、麦克风)
3. 查看控制台日志确认捕获是否启动

### Q: 如何使用真正的 Meta Ray-Ban 眼镜？
A: 需要：
1. 从 Meta 开发者门户下载 Meta Wearables SDK
2. 集成 SDK 到项目中
3. 替换 `MetaWearablesDATAdapter` 中的 AVCaptureSession 为 Meta SDK 的数据源
4. 具体参考: https://wearables.developer.meta.com/docs/build-integration-ios

## 文件结构

```
Swift/EmotionApp/
├── EmotionApp/                  # App 主体
│   ├── EmotionAppApp.swift     # App 入口和配置
│   ├── ContentView.swift        # 主界面
│   └── Info.plist              # 权限配置
│
├── Adapters/                    # 适配器层
│   ├── URLSessionWebSocketClient.swift  # WebSocket 客户端
│   ├── MetaWearablesDATAdapter.swift    # Meta 适配器
│   ├── CameraVideoProvider.swift        # 备用: 摄像头视频提供者
│   └── MicrophoneAudioProvider.swift    # 备用: 麦克风音频提供者
│
└── EmotionApp.xcodeproj        # Xcode 项目文件
```

## 依赖关系

- **EmotionCore**: 核心逻辑 (编码、数据处理、协议)
- **EmotionUI**: UI 组件 (情绪分析视图)
- **AVFoundation**: 视频和音频捕获
- **Foundation**: WebSocket 和基础功能

## 下一步

1. 集成 Meta Wearables SDK 用于真正的 Ray-Ban 眼镜
2. 添加离线情绪分析功能
3. 实现安全的 token 存储
4. 添加连接质量指示器
5. 优化错误处理和重试机制
