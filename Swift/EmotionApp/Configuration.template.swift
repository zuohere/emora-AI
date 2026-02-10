// Configuration.swift
// 用于配置 EmotionApp 的服务器地址和其他设置
// 复制此文件为 Configuration.swift 并修改值

import Foundation

// ========================
// 服务器配置
// ========================

/// WebSocket 服务器地址
/// 示例: "wss://emotion-api.example.com/ws"
let WEBSOCKET_URL = "wss://your-emotion-server.com/ws"

/// 认证 Token (可选)
/// 如果服务器需要认证，在此处填写
/// 示例: "Bearer eyJhbGciOiJIU..."
let AUTH_TOKEN: String? = nil

// ========================
// 视频配置
// ========================

/// 视频宽度 (像素)
let VIDEO_WIDTH = 640

/// 视频高度 (像素)
let VIDEO_HEIGHT = 480

/// 视频帧率 (FPS)
let VIDEO_FPS = 30

// ========================
// 音频配置
// ========================

/// 音频采样率 (Hz)
/// 推荐值: 16000, 44100
let AUDIO_SAMPLE_RATE = 16000

/// 音频通道数
/// 1 = 单声道, 2 = 立体声
let AUDIO_CHANNELS = 1

// ========================
// 其他配置
// ========================

/// 是否启用调试日志
let ENABLE_DEBUG_LOG = true

/// 连接超时时间 (秒)
let CONNECTION_TIMEOUT = 30

/// 重连间隔 (秒)
let RECONNECT_INTERVAL = 5
