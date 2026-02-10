# Emotion for Meta (starter)

This repository contains an initial proposal and starter Swift packages for extracting the emotion analysis feature into a standalone iOS app targeting Meta wearables (e.g., Ray‑Ban).

## Key parts:
- EmotionCore: core logic (Swift Package)
- EmotionUI: UI (Swift Package)
- EmotionApp: iOS app with Meta Wearables adapter implementation
- Adapters: WebSocket client and Meta Wearables DAT adapter

## Current Implementation Status

### ✅ Implemented Components:

1. **WebSocket Client** ([Adapters/URLSessionWebSocketClient.swift](Swift/EmotionApp/Adapters/URLSessionWebSocketClient.swift))
   - URLSession-based WebSocket implementation
   - Automatic reconnection support
   - Binary and text message handling
   - Connection lifecycle callbacks

2. **Meta Wearables DAT Adapter** ([Adapters/MetaWearablesDATAdapter.swift](Swift/EmotionApp/Adapters/MetaWearablesDATAdapter.swift))
   - Implements `VideoProvider` protocol for camera video capture
   - Implements `AudioProvider` protocol for microphone audio capture
   - AVCaptureSession integration
   - AVAudioEngine integration
   - Real-time frame and audio chunk callbacks

3. **EmotionCoreManager Integration**
   - Configured to use MetaWearablesDATAdapter for both video and audio
   - WebSocket client connection on app launch
   - H264 video encoding
   - Audio encoding and streaming
   - Emotion analysis result display

4. **App Configuration** ([EmotionAppApp.swift](Swift/EmotionApp/EmotionApp/EmotionAppApp.swift))
   ```swift
   let wsClient = URLSessionWebSocketClient()
   let metaAdapter = MetaWearablesDATAdapter()

   EmotionCoreManager.shared.configure(
       wsClient: wsClient,
       videoProvider: metaAdapter,
       audioProvider: metaAdapter
   )
   ```

## Getting Started

### Prerequisites
- Xcode 15+
- iOS 15.0+
- Camera and microphone permissions (configured in Info.plist)

### Configuration

1. **Update WebSocket URL**
   Edit `EmotionApp/EmotionAppApp.swift` and replace the WebSocket URL:
   ```swift
   if let wsUrl = URL(string: "wss://your-emotion-server.com/ws") {
       wsClient.connect(url: wsUrl, token: nil)
   }
   ```

2. **Add Authentication Token** (if required)
   ```swift
   wsClient.connect(url: wsUrl, token: "your-auth-token")
   ```

3. **Run the App**
   - Open `Swift/EmotionApp/EmotionApp.xcodeproj` in Xcode
   - Select your device or simulator
   - Build and run (Cmd+R)

### Usage

1. Launch the app
2. Tap "开始采集" button to start emotion analysis
3. Camera and microphone will begin capturing
4. Video and audio data will be streamed to the WebSocket server
5. Emotion analysis results will appear in the UI

## Architecture

```
EmotionApp
├── App Layer (EmotionAppApp.swift)
│   ├── EmotionCoreManager (shared)
│   ├── URLSessionWebSocketClient
│   └── MetaWearablesDATAdapter
│
├── UI Layer (ContentView.swift)
│   ├── EmotionAnalysisView (from EmotionUI)
│   └── Control Buttons
│
├── Adapter Layer
│   ├── URLSessionWebSocketClient (WebSocket)
│   └── MetaWearablesDATAdapter (Video + Audio)
│
└── Core Layer (EmotionCore)
    ├── WebSocketClient protocol
    ├── VideoProvider/AudioProvider protocols
    ├── H264Encoder
    ├── AudioEncoder
    └── Data streaming logic
```

## Next Steps

- [ ] Integrate Meta Wearables SDK for direct Ray-Ban integration
- [ ] Add offline emotion analysis capability
- [ ] Implement secure token storage
- [ ] Add connection quality indicators
- [ ] Implement error handling and retry logic

## Meta Wearables SDK
https://wearables.developer.meta.com/docs/build-integration-ios

## Notes:
- The Meta SDK is distributed via the developer portal; follow their docs to download and integrate the SDK into the App target.
- Use developer mode for easier hardware testing.
- Do not hardcode API tokens or WS URLs; inject at runtime or use secure storage.
- Currently using iPhone camera/microphone as a fallback until Meta SDK integration
