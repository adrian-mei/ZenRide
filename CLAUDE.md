# FashodaMap

This app is called **FashodaMap** (repo folder: ZenRide).
It is an iOS SwiftUI app — a gamified, cozy Animal Crossing-themed driving companion.

## Key Facts
- Build tool: `xcodegen generate` → `xcodebuild`
- Scheme: `ZenRide`, target: `iPhone 17 Pro` simulator
- All logging via `Log.*` — never `print()` or `NSLog()`
- Persistence: SwiftData (drives) + UserDefaults (player XP, vehicles, quests)
- No remote backend — fully local
