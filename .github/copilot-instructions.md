<!-- Copilot / AI agent instructions for the Emotion repo -->
# Quick orientation

This repository is a small Swift mono-repo split into three logical parts under `Swift/`:
- `EmotionCore` — core runtime and runtime abstractions (providers, `EmotionCoreManager`).
- `EmotionUI` — SwiftUI views that subscribe to `EmotionCoreManager` (see `EmotionAnalysisView`).
- `EmotionApp` — the app target where platform adapters (camera/mic/wearables) and concrete wiring live.

Key files to inspect when making changes:
- `Swift/EmotionCore/Sources/EmotionCore/EmotionCoreManager.swift` — central singleton, DI points, and Combine publishers.
- `Swift/EmotionCore/Sources/EmotionCore/Providers.swift` — provider protocols (`VideoProvider`, `AudioProvider`, `WearablesProvider`).
- `Swift/EmotionUI/Sources/EmotionUI/EmotionAnalysis.swift` — example UI consuming `EmotionCoreManager` via `@ObservedObject`.
- `Swift/EmotionApp/Adapters/MetaWearablesDATAdapter.swift` — example adapter skeleton for platform SDK integration.

# Architecture notes (what an agent should assume)
- `EmotionCore` is framework-agnostic: it defines protocols and a manager that exposes `@Published` state for the UI.
- Concrete implementations live in the `EmotionApp` target (adapters). The Core intentionally accepts injected dependencies:
  - `WebSocketClient` is injected into `EmotionCoreManager` for testability.
  - `VideoProvider`, `AudioProvider`, and `WearablesProvider` are injected and expose callbacks (e.g. `onFrame`).
- `EmotionUI` depends on `EmotionCore` via a local package dependency (see `EmotionUI/Package.swift`).

# Common workflows and commands
- Build a package: run `swift build` inside the package folder (e.g. `cd Swift/EmotionCore && swift build`).
- Run tests: `cd Swift/EmotionCore && swift test` (each package has a `Tests` target; run per-package).
- Open the app in Xcode for full app wiring and SDK integration — the app target contains platform adapters.

# Project-specific conventions and patterns
- Dependency injection by field: `EmotionCoreManager.shared` exposes public `videoProvider`, `audioProvider`, `wearablesProvider`, and `wsClient` for wiring at app start.
- Use `@Published` properties on `EmotionCoreManager` for state the UI consumes (e.g. `emotionScores`, `dominantEmotion`).
- Providers are lightweight callback-based protocols; adapters should map SDK callbacks to the provider callbacks (see `MetaWearablesDATAdapter.swift`).
- Keep platform/SDK code inside `EmotionApp` and leave `EmotionCore` pure Swift (no SDK imports).

# Examples agents can use when editing/adding code
- Configure manager in app bootstrap:
  - `EmotionCoreManager.shared.configure(wsClient: myWs, videoProvider: myVideo, audioProvider: myAudio)`
- Example provider implementation pattern (see `MetaWearablesDATAdapter.swift`):
  - Adapter implements `VideoProvider`/`AudioProvider` and forwards SDK frames/chunks to `onFrame` / `onAudioChunk`.

# Integration and testing hints
- Because `WebSocketClient` is an injectable protocol, implement a lightweight test stub for unit tests that calls `onMessageData` to simulate server messages.
- To iterate on UI quickly, update `EmotionCoreManager.shared` values (or add small debug injection helpers) so the `EmotionAnalysisView` receives changes via Combine.

# What not to change lightly
- Do not add platform SDK imports into `EmotionCore` sources; keep cross-platform core decoupled.
- Avoid replacing the `shared` singleton pattern without updating UI wiring (`@ObservedObject var manager: EmotionCoreManager = .shared`).

# If you need more context
- Inspect `Swift/EmotionCore/Package.swift` and `Swift/EmotionUI/Package.swift` to see package links and targets.
- Look at `Swift/EmotionApp/Adapters` for concrete wiring examples.

If anything is missing or unclear, tell me which area you want expanded (build steps, unit-test examples, or adapter templates) and I'll refine this file.
