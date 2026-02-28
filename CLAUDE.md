# FashodaMap

This app is called **FashodaMap** (repo folder: ZenRide).
It is an iOS SwiftUI app — a gamified, cozy Animal Crossing-themed driving companion.

## Key Facts
- Build tool: `xcodegen generate` → `xcodebuild`
- Scheme: `ZenRide`, target: `iPhone 17 Pro` simulator
- All logging via `Log.*` — never `print()` or `NSLog()`
- Persistence: SwiftData (drives) + UserDefaults (player XP, vehicles, quests)
- No remote backend — fully local

## Product & Data Decisions
- **Speed Camera Data**: The app utilizes a static `sf_speed_cameras.json` dataset because San Francisco is the pilot program and the first city in the US to have speed cameras installed. This real-world pilot anchors the core "Bunny Police" routing and radar gameplay.
- **Global Gameplay Support**: To ensure the "50% app / 50% game" hybrid experience works for users worldwide, the app dynamically generates localized "mock" speed cameras (patrols) if a user is located more than 50km outside of San Francisco.
