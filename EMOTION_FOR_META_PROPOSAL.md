# Emotion 功能拆分（面向 Meta Ray‑Ban 可穿戴）

目标

- 将当前 emotion 功能抽成独立的 iOS 应用/模块，继续运行在 Meta Ray‑Ban（Meta wearables）眼镜上。
- 核心逻辑做成可复用的 Swift Package（EmotionCore）。
- UI 做成独立模块（EmotionUI）。
- 尽量去除对 turboemta 的依赖；可以依赖 Meta 的可穿戴 SDK（facebook/meta-wearables-dat-ios）和 Meta AI（若有 iOS SDK 或通过后端 API）。
- Python client 保持为标准版（用于本地联调与测试）。
- 不需要迁移或处理 gateway 文件。

推荐仓库结构（示例）

- README.md
- LICENSE
- .gitignore
- /Swift
  - /EmotionCore (Swift Package)
    - Package.swift
    - Sources/EmotionCore/Providers.swift
    - Sources/EmotionCore/EmotionCoreManager.swift
    - Sources/EmotionCore/Encoders/*.swift
  - /EmotionUI (Swift Package)
    - Package.swift
    - Sources/EmotionUI/EmotionAnalysisView.swift
  - /EmotionApp (示例 App target)
    - EmotionApp.xcodeproj
    - Info.plist
    - Adapters/MetaWearablesDATAdapter.swift
- /PythonClient (你的标准 Python client，用于联调)
- /Docs (集成说明、运行示例、CI 配置)
- /.github/workflows (CI：lint、测试、打包)

说明：
- EmotionCore：核心逻辑（WebSocket、编码、消息协议、状态管理），不依赖 SwiftUI，便于在多个 App/target 之间复用和单元测试。
- EmotionUI：独立的 SwiftUI 模块，仅负责视图呈现，依赖 EmotionCore 暴露的 ObservableObject。
- EmotionApp：真实运行的 App，把 Meta SDK 的适配层实现为 VideoProvider/AudioProvider，把设备帧/音频注入 EmotionCore。

关键设计要点

- Provider 抽象：定义 VideoProvider / AudioProvider / WearablesProvider 协议，EmotionCore 仅依赖这些协议，App 层实现具体 provider（如 MetaWearablesDATAdapter）。
- WebSocket 抽象：定义 WebSocketClient 协议，运行时注入，便于本地 mock 与替换实现。
- 编码封装：把 H264（视频）和 AAC（音频）编码逻辑封装为 VideoEncoder/AudioEncoder。
- 不在代码中写死 token/URL：通过运行时注入、配置文件或 Keychain 注入 WS_URL / API_TOKEN。
- 权限：Info.plist 需包含 NSCameraUsageDescription、NSMicrophoneUsageDescription、NSBluetoothAlwaysUsageDescription（如需）和 NSLocalNetworkUsageDescription（如需）。
- 性能：把编码/发送放到后台队列，使用 DispatchSemaphore 控制并发，保留 OSLog/MetricKit hook（按需启用）。

Meta SDK 集成

- 首选把 https://github.com/facebook/meta-wearables-dat-ios 加为 App target 的依赖（SPM 或作为子模块/框架）。
- 在 Adapter 中把 SDK 回调转换为 UIImage/CVPixelBuffer（视频）和 Data（音频）并调用 EmotionCore 的注入接口。
- 我可以基于该 SDK 的文档帮你实现具体的 Adapter（需要 SDK 的回调/类名/示例）。

Python 客户端（联调）

- 保留并使用已有的 Python client 作为本地后端模拟或真实后端联调工具。
- 在 Docs 中提供如何运行 client（.env 示例、运行命令）。

示例文件模版（可直接复制到仓库）
(以下为示例文件，见后面的代码块)
