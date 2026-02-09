# Emotion for Meta (starter)

This repository contains an initial proposal and starter Swift packages for extracting the emotion analysis feature into a standalone iOS app targeting Meta wearables (e.g., Ray‑Ban).

Key parts:
- EmotionCore: core logic (Swift Package)
- EmotionUI: UI (Swift Package)
- EmotionApp: example App target with Adapter skeleton for Meta SDK

Meta Wearables SDK: https://wearables.developer.meta.com/docs/build-integration-ios

Notes:
- The Meta SDK is distributed via the developer portal; follow their docs to download and integrate the SDK into the App target.
- Use developer mode for easier hardware testing.
- Do not hardcode API tokens or WS URLs; inject at runtime or use secure storage.
